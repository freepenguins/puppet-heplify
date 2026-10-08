# frozen_string_literal: true

require 'spec_helper'

describe 'heplify::server' do
  shipped_checksums = {
    'amd64' => '6077a620cbcb13791fac06f9a3d30379fa088e4b1b87dbdde4b4dc001ba808b0',
    'arm64' => 'a0b66f0b02b529bf10bc4b193ea36fc02ee7a10e13239537c55ecf950f769d77',
  }
  release_url = 'https://github.com/sipcapture/heplify-server/releases/download/v1.60.1'
  binary = '/opt/heplify-server/heplify-server-1.60.1'
  config_file = '/etc/heplify-server.toml'
  unit_file = '/etc/systemd/system/heplify-server.service'

  # aarch64 fact sets exist only for some releases; those exercise the arm64 binary.
  on_supported_os(hardwaremodels: ['x86_64', 'aarch64']).each do |os, os_facts|
    context "on #{os}" do
      arm = ['aarch64', 'arm64'].include?(os_facts[:os]['architecture'])
      arch = arm ? 'arm64' : 'amd64'
      asset = arm ? 'heplify-server-arm64' : 'heplify-server'

      let(:facts) { os_facts }

      context 'with default parameters' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('heplify::server::install').that_comes_before('Class[heplify::server::config]') }
        it { is_expected.to contain_class('heplify::server::install').that_notifies('Class[heplify::server::service]') }
        it { is_expected.to contain_class('heplify::server::config').that_notifies('Class[heplify::server::service]') }
        it { is_expected.to contain_group('heplify-server').with(ensure: 'present', system: true) }
        it { is_expected.to contain_user('heplify-server').with(system: true, gid: 'heplify-server', shell: '/usr/sbin/nologin') }
        it { is_expected.to contain_file(binary).with(ensure: 'file', mode: '0755', source: "#{release_url}/#{asset}") }
        it { is_expected.to contain_file(binary).with(checksum: 'sha256', checksum_value: shipped_checksums[arch]) }
        it { is_expected.to contain_file('/usr/local/bin/heplify-server').with(ensure: 'link', target: binary) }
        it { is_expected.to contain_file(config_file).with(owner: 'root', group: 'heplify-server', mode: '0640', show_diff: true) }
        it { is_expected.to contain_file(config_file).with_content(%r{^HEPAddr = "0\.0\.0\.0:9060"$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^DBShema = "homer7"$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^DBDriver = "postgres"$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^DBUser = "homer"$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^DBConfTable = "homer_config"$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^PromAddr = ""$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^DBDropDays = 14$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^LogStd = true$}) }
        it { is_expected.to contain_file(config_file).without_content(%r{^DBPass}) }
        it { is_expected.to contain_file(unit_file).with_content(%r{^ExecStart=/usr/local/bin/heplify-server -config=/etc/heplify-server\.toml$}) }
        it { is_expected.to contain_file(unit_file).with_content(%r{^User=heplify-server$}) }
        it { is_expected.to contain_file(unit_file).with_content(%r{^After=network-online\.target postgresql\.service$}) }
        it { is_expected.to contain_file(unit_file).with_content(%r{^WorkingDirectory=/var/log/heplify-server$}) }
        it { is_expected.to contain_exec('heplify-server-systemctl-daemon-reload').with_refreshonly(true).that_subscribes_to("File[#{unit_file}]") }
        it { is_expected.to contain_service('heplify-server').with(ensure: 'running', enable: true).that_requires('Exec[heplify-server-systemctl-daemon-reload]') }
      end

      context 'with a database password' do
        let(:params) { { db_password: sensitive('s3cr"et') } }

        it { is_expected.to contain_file(config_file).with_content(%r{^DBPass = "s3cr\\"et"$}) }
        it { is_expected.to contain_file(config_file).with_show_diff(false) }
      end

      context 'with settings from Hiera' do
        let(:hiera_config) { 'spec/fixtures/hiera/hiera.yaml' }

        it { is_expected.to contain_file(config_file).with_content(%r{^DBAddr = "db\.example\.com:5432"$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^PromAddr = "127\.0\.0\.1:9096"$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^DBShema = "homer7"$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^DBPass = "from-hiera"$}) }
        it { is_expected.to contain_file(config_file).with_show_diff(false) }
      end

      context 'with array and other secret settings' do
        let(:params) { { settings: { 'DBUser' => 'homer', 'DiscardMethod' => ['OPTIONS', 'NOTIFY'], 'LokiHEPFilter' => [1, 5], 'ConfigHTTPPW' => 'x' } } }

        it { is_expected.to contain_file(config_file).with_content(%r{^DiscardMethod = \["OPTIONS", "NOTIFY"\]$}) }
        it { is_expected.to contain_file(config_file).with_content(%r{^LokiHEPFilter = \[1, 5\]$}) }
        it { is_expected.to contain_file(config_file).with_show_diff(false) }
      end

      context 'with a superuser database account' do
        let(:params) { { settings: { 'DBUser' => 'postgres' } } }

        it { is_expected.to compile.and_raise_error(%r{DBUser 'postgres' makes heplify-server create a database user 'homer_user'}) }
      end

      context 'with settings that leave out DBUser' do
        let(:params) { { settings: { 'HEPAddr' => '0.0.0.0:9060' } } }

        it { is_expected.to compile.and_raise_error(%r{DBUser 'root'}) }
      end

      context 'with a superuser database account explicitly allowed' do
        let(:params) { { settings: { 'DBUser' => 'postgres' }, allow_db_superuser: true } }

        it { is_expected.to compile.with_all_deps }
      end

      context 'with a config file name heplify-server would ignore' do
        let(:params) { { config_file: '/etc/heplify-server.conf' } }

        it { is_expected.to compile.and_raise_error(%r{config_file}) }
      end

      context 'with install_method => package' do
        let(:params) { { install_method: 'package' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('heplify-server').with_ensure('1.60.1') }
        it { is_expected.not_to contain_file(binary) }
      end

      context 'with install_method => none' do
        let(:params) { { install_method: 'none' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_package('heplify-server') }
        it { is_expected.not_to contain_file('/opt/heplify-server') }
      end

      context 'with manage_user => false' do
        let(:params) { { manage_user: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_user('heplify-server') }
        it { is_expected.not_to contain_group('heplify-server') }
      end

      context 'with manage_service => false' do
        let(:params) { { manage_service: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_service('heplify-server') }
        it { is_expected.not_to contain_file(unit_file) }
      end

      context 'with the agent on the same node' do
        let(:pre_condition) { 'include heplify' }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_service('heplify') }
        it { is_expected.to contain_service('heplify-server') }
      end

      context 'on an architecture without a release binary' do
        let(:facts) { os_facts.merge(os: os_facts[:os].merge('architecture' => 'ppc64le')) }

        it { is_expected.to compile.and_raise_error(%r{heplify::server: no release binary for architecture ppc64le}) }
      end
    end
  end
end
