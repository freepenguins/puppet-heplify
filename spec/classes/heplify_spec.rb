# frozen_string_literal: true

require 'spec_helper'
require 'json'

describe 'heplify' do
  shipped_checksums = {
    'amd64' => 'c91927c793248f153bd07725a39b94145ef893a364d3029e64f4e1f9769a2faa',
    'arm64' => '19783aa73964082ae9b94a6ef893c457289ad122fe44f605e194478177522151',
  }
  release_url = 'https://github.com/sipcapture/heplify/releases/download'
  binary = '/opt/heplify/heplify-2.0.28'
  config_file = '/etc/heplify/heplify.json'
  unit_file = '/etc/systemd/system/heplify.service'

  # aarch64 fact sets exist only for some releases; those exercise the arm64 binary.
  on_supported_os(hardwaremodels: ['x86_64', 'aarch64']).each do |os, os_facts|
    context "on #{os}" do
      arch = ['aarch64', 'arm64'].include?(os_facts[:os]['architecture']) ? 'arm64' : 'amd64'
      hostname = os_facts[:networking]['hostname']

      let(:facts) { os_facts }
      let(:heplify_json) { JSON.parse(catalogue.resource('File', config_file)[:content]) }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('heplify::install').that_comes_before('Class[heplify::config]') }
        it { is_expected.to contain_class('heplify::install').that_notifies('Class[heplify::service]') }
        it { is_expected.to contain_class('heplify::config').that_notifies('Class[heplify::service]') }
        it { is_expected.to contain_file(binary).with(ensure: 'file', mode: '0755', source: "#{release_url}/2.0.28/heplify_linux_#{arch}") }
        it { is_expected.to contain_file(binary).with(checksum: 'sha256', checksum_value: shipped_checksums[arch]) }
        it { is_expected.to contain_file('/usr/local/bin/heplify').with(ensure: 'link', target: binary) }
        it { is_expected.to contain_file(config_file).with(owner: 'root', mode: '0640', show_diff: true) }
        it { is_expected.to contain_file(unit_file).with_content(%r{^ExecStart=/usr/local/bin/heplify -config /etc/heplify/heplify\.json$}) }
        it { is_expected.to contain_file(unit_file).with_content(%r{^After=network-online\.target heplify-server\.service$}) }
        it { is_expected.to contain_file(unit_file).with_content(%r{^CapabilityBoundingSet=CAP_NET_RAW CAP_NET_ADMIN$}) }
        it { is_expected.to contain_exec('heplify-systemctl-daemon-reload').with_refreshonly(true).that_subscribes_to("File[#{unit_file}]") }
        it { is_expected.to contain_service('heplify').with(ensure: 'running', enable: true).that_requires('Exec[heplify-systemctl-daemon-reload]') }

        it 'captures SIP only, on every interface' do
          expect(heplify_json).to include(
            'socket' => [include('device' => 'any', 'socket_type' => 'afpacket', 'capture_mode' => ['SIP'], 'transport_profile' => ['hep'])],
            'protocol' => [{ 'name' => 'SIP', 'description' => 'SIP', 'min_port' => 5060, 'max_port' => 5090, 'protocol' => ['udp', 'tcp'] }],
            'rtcp_settings' => { 'active' => false },
          )
        end

        it 'sends HEPv3 over UDP to a heplify-server on the same host' do
          expect(heplify_json['transport']).to eq([{ 'name' => 'hep', 'active' => true, 'protocol' => 'HEPv3', 'host' => '127.0.0.1', 'port' => 9060, 'transport' => 'udp', 'password' => '' }])
        end

        it 'identifies the node by hostname' do
          expect(heplify_json['system_settings']).to eq('node_name' => hostname, 'node_id' => 2002, 'node_pw' => '')
        end
      end

      context 'with a remote heplify-server over TCP and a HEP password' do
        let(:params) do
          {
            interface: 'eth0',
            hep_host: 'homer.example.com',
            hep_port: 9061,
            hep_transport: 'tcp',
            hep_password: sensitive('s3cret'),
            node_name: 'sbc01',
            node_id: 2101,
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_file(config_file).with_show_diff(false) }

        it 'points the transport at the remote server' do
          expect(heplify_json).to include(
            'socket' => [include('device' => 'eth0')],
            'transport' => [include('host' => 'homer.example.com', 'port' => 9061, 'transport' => 'tcp', 'password' => 's3cret')],
            'system_settings' => { 'node_name' => 'sbc01', 'node_id' => 2101, 'node_pw' => 's3cret' },
          )
        end
      end

      context 'with RTCP capture and custom SIP ports' do
        let(:params) { { capture_mode: ['SIP', 'RTCP'], sip_port_min: 5060, sip_port_max: 5080 } }

        it 'lists exactly the captured protocols' do
          expect(heplify_json).to include(
            'protocol' => [include('name' => 'SIP', 'min_port' => 5060, 'max_port' => 5080), include('name' => 'RTCP', 'min_port' => 1024, 'max_port' => 65_535)],
            'rtcp_settings' => { 'active' => true },
          )
        end
      end

      context 'with filtering' do
        let(:params) { { discard_methods: ['OPTIONS', 'NOTIFY'], deduplicate: true } }

        it 'discards methods and deduplicates' do
          expect(heplify_json).to include('sip_settings' => { 'discard_methods' => ['OPTIONS', 'NOTIFY'], 'deduplicate' => true }, 'hep_settings' => { 'deduplicate' => true })
        end
      end

      context 'with config_overrides' do
        let(:params) { { config_overrides: { 'prometheus_settings' => { 'active' => true, 'port' => 9096 }, 'system_settings' => { 'node_id' => 3000 } } } }

        it 'deep-merges the overrides over the generated config' do
          expect(heplify_json).to include('prometheus_settings' => { 'active' => true, 'port' => 9096 }, 'system_settings' => include('node_id' => 3000, 'node_name' => hostname))
        end
      end

      context 'with an explicit checksum' do
        let(:params) { { checksum: 'a' * 64 } }

        it { is_expected.to contain_file(binary).with(checksum: 'sha256', checksum_value: 'a' * 64) }
      end

      context 'with a version that has no known checksum' do
        let(:params) { { version: '9.9.9' } }

        it { is_expected.to contain_file('/opt/heplify/heplify-9.9.9').without_checksum.without_checksum_value }
        it { is_expected.to contain_file('/usr/local/bin/heplify').with_target('/opt/heplify/heplify-9.9.9') }
      end

      context 'with a download mirror' do
        let(:params) { { download_base_url: 'https://mirror.example.com/heplify' } }

        it { is_expected.to contain_file(binary).with_source("https://mirror.example.com/heplify/2.0.28/heplify_linux_#{arch}") }
      end

      context 'with install_method => package' do
        let(:params) { { install_method: 'package', version: '2.0.28' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('heplify').with_ensure('2.0.28') }
        it { is_expected.not_to contain_file(binary) }
        it { is_expected.not_to contain_file('/usr/local/bin/heplify') }
      end

      context 'with install_method => none' do
        let(:params) { { install_method: 'none' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('heplify') }
        it { is_expected.not_to contain_file('/opt/heplify') }
      end

      context 'with manage_service => false' do
        let(:params) { { manage_service: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_service('heplify') }
        it { is_expected.not_to contain_file(unit_file) }
      end

      context 'with a stopped, disabled service and extra ordering' do
        let(:params) { { service_ensure: 'stopped', service_enable: false, after_units: ['docker.service'] } }

        it { is_expected.to contain_service('heplify').with(ensure: 'stopped', enable: false) }
        it { is_expected.to contain_file(unit_file).with_content(%r{^After=network-online\.target docker\.service$}) }
      end

      context 'with sip_port_min greater than sip_port_max' do
        let(:params) { { sip_port_min: 6000, sip_port_max: 5060 } }

        it { is_expected.to compile.and_raise_error(%r{sip_port_min \(6000\) is greater than sip_port_max \(5060\)}) }
      end

      context 'with an invalid capture mode' do
        let(:params) { { capture_mode: ['SIP', 'XMPP'] } }

        it { is_expected.to compile.and_raise_error(%r{capture_mode}) }
      end

      context 'on an architecture without a release binary' do
        let(:facts) { os_facts.merge(os: os_facts[:os].merge('architecture' => 'ppc64le')) }

        it { is_expected.to compile.and_raise_error(%r{no release binary for architecture ppc64le}) }
      end
    end
  end
end
