# @summary Install, configure and run the HOMER heplify capture agent (v2.x).
#
# Every parameter is resolved through Hiera (automatic parameter lookup).
# Module defaults live in data/common.yaml: capture SIP on all interfaces and
# send HEPv3 over UDP to a heplify-server on the same host (127.0.0.1:9060).
#
# @param version            heplify release tag, e.g. '2.0.28'
# @param install_method     'binary' downloads the release binary, 'package'
#                           installs $package_name from a repo you already
#                           manage, 'none' leaves installation to you
# @param download_base_url  Base URL for release binaries (point at a mirror
#                           if nodes cannot reach GitHub)
# @param checksum           sha256 of the binary; strongly recommended
# @param package_name       Package name when install_method is 'package'
# @param install_dir        Where versioned binaries are stored
# @param bin_path           Path the service executes
# @param config_file        Path of the generated JSON config
# @param interface          Capture device ('any', 'eth0', ...)
# @param socket_type        'afpacket' or 'pcap'
# @param promisc            Put the interface in promiscuous mode
# @param capture_mode       Protocols to capture, e.g. ['SIP'] or ['SIP','RTCP']
# @param sip_port_min       Lowest SIP port to capture
# @param sip_port_max       Highest SIP port to capture
# @param tcp_reassembly     Reassemble TCP streams (needed for SIP over TCP)
# @param sip_reassembly     Reassemble SIP messages fragmented across TCP segments
# @param ip_defrag          Reassemble IP fragments
# @param vlan               Capture VLAN-tagged traffic
# @param bpf_filter         Custom BPF filter (overrides the generated one)
# @param hep_host           HEP server address
# @param hep_port           HEP server port
# @param hep_transport      'udp', 'tcp' or 'tls'
# @param hep_password       HEP node password, if the server requires one
# @param node_name          HEP node name reported to HOMER
# @param node_id            HEP node ID reported to HOMER
# @param deduplicate        Drop duplicate packets (useful with interface 'any')
# @param discard_methods    SIP methods to drop, e.g. ['OPTIONS','NOTIFY']
# @param log_level          'debug', 'info', 'warn' or 'error'
# @param config_overrides   Hash deep-merged over the generated config, for
#                           any heplify.json key this class has no parameter for
# @param manage_service     Manage the systemd unit and service
# @param service_name       systemd service name
# @param service_ensure     'running' or 'stopped'
# @param service_enable     Start at boot
# @param after_units        Units heplify is ordered after
class heplify (
  String[1]                                $version,
  Enum['binary', 'package', 'none']        $install_method,
  String[1]                                $download_base_url,
  Optional[Pattern[/\A[0-9a-f]{64}\z/]]    $checksum,
  String[1]                                $package_name,
  Stdlib::Absolutepath                     $install_dir,
  Stdlib::Absolutepath                     $bin_path,
  Stdlib::Absolutepath                     $config_file,
  String[1]                                $interface,
  Enum['afpacket', 'pcap']                 $socket_type,
  Boolean                                  $promisc,
  Array[Enum['SIP', 'RTCP', 'RTP', 'DNS', 'LOG', 'DIAMETER'], 1] $capture_mode,
  Stdlib::Port                             $sip_port_min,
  Stdlib::Port                             $sip_port_max,
  Boolean                                  $tcp_reassembly,
  Boolean                                  $sip_reassembly,
  Boolean                                  $ip_defrag,
  Boolean                                  $vlan,
  String                                   $bpf_filter,
  Stdlib::Host                             $hep_host,
  Stdlib::Port                             $hep_port,
  Enum['udp', 'tcp', 'tls']                $hep_transport,
  Variant[String, Sensitive[String]]       $hep_password,
  String[1]                                $node_name,
  Integer[0]                               $node_id,
  Boolean                                  $deduplicate,
  Array[String[1]]                         $discard_methods,
  Enum['debug', 'info', 'warn', 'error']   $log_level,
  Hash                                     $config_overrides,
  Boolean                                  $manage_service,
  String[1]                                $service_name,
  Stdlib::Ensure::Service                  $service_ensure,
  Boolean                                  $service_enable,
  Array[String[1]]                         $after_units,
) {
  if $sip_port_min > $sip_port_max {
    fail("heplify: sip_port_min (${sip_port_min}) is greater than sip_port_max (${sip_port_max})")
  }

  $password = $hep_password ? {
    Sensitive => $hep_password.unwrap,
    default   => $hep_password,
  }

  # ---------------------------------------------------------------- install
  case $install_method {
    'binary': {
      $arch = $facts['os']['architecture'] ? {
        /^(x86_64|amd64)$/  => 'amd64',
        /^(aarch64|arm64)$/ => 'arm64',
        default             => fail("heplify: no release binary for ${facts['os']['architecture']}"),
      }
      $versioned_bin = "${install_dir}/heplify-${version}"
      $checksum_opts = $checksum ? {
        undef   => {},
        default => { 'checksum' => 'sha256', 'checksum_value' => $checksum },
      }

      file { $install_dir:
        ensure => directory,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }

      file { $versioned_bin:
        ensure => file,
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
        source => "${download_base_url}/${version}/heplify_linux_${arch}",
        *      => $checksum_opts,
      }

      # Upgrades and rollbacks are a symlink flip; old versions stay on disk.
      file { $bin_path:
        ensure => link,
        target => $versioned_bin,
      }

      $install_resource = File[$bin_path]
    }
    'package': {
      package { $package_name:
        ensure => $version,
      }
      $install_resource = Package[$package_name]
    }
    default: {
      $install_resource = undef
    }
  }

  # ----------------------------------------------------------------- config
  # heplify builds its kernel BPF filter from every entry in "protocol", so
  # only the captured protocols may be listed. Listing RTP/RTCP (1024-65535)
  # on a SIP-only agent would pull nearly all UDP into userspace, including
  # the agent's own HEP packets on loopback.
  $protocol_defs = {
    'SIP'      => { 'min_port' => $sip_port_min, 'max_port' => $sip_port_max, 'protocol' => ['udp', 'tcp'] },
    'RTCP'     => { 'min_port' => 1024, 'max_port' => 65535, 'protocol' => ['udp'] },
    'RTP'      => { 'min_port' => 1024, 'max_port' => 65535, 'protocol' => ['udp'] },
    'DNS'      => { 'min_port' => 53,   'max_port' => 53,    'protocol' => ['udp', 'tcp'] },
    'DIAMETER' => { 'min_port' => 3868, 'max_port' => 3868,  'protocol' => ['tcp', 'sctp'] },
  }
  $protocols = $capture_mode.unique.filter |$mode| { $mode in $protocol_defs }.map |$mode| {
    { 'name' => $mode, 'description' => $mode } + $protocol_defs[$mode]
  }

  $generated_config = {
    'socket'          => [
      {
        'name'              => 'default',
        'active'            => true,
        'socket_type'       => $socket_type,
        'transport_profile' => ['hep'],
        'device'            => $interface,
        'promisc'           => $promisc,
        'tcp_reasm'         => $tcp_reassembly,
        'sip_reasm'         => $sip_reassembly,
        'ipfragments'       => $ip_defrag,
        'vlan'              => $vlan,
        'snap_len'          => 8192,
        'capture_mode'      => $capture_mode,
        'bpf_filter'        => $bpf_filter,
      },
    ],
    'transport'       => [
      {
        'name'      => 'hep',
        'active'    => true,
        'protocol'  => 'HEPv3',
        'host'      => $hep_host,
        'port'      => $hep_port,
        'transport' => $hep_transport,
        'password'  => $password,
      },
    ],
    'protocol'        => $protocols,
    'log_settings'    => {
      'active' => true,
      'level'  => $log_level,
      'stdout' => true,
      'json'   => false,
    },
    'sip_settings'    => {
      'discard_methods' => $discard_methods,
      'deduplicate'     => $deduplicate,
    },
    'hep_settings'    => {
      'deduplicate' => $deduplicate,
    },
    'rtcp_settings'   => {
      'active' => 'RTCP' in $capture_mode,
    },
    'system_settings' => {
      'node_name' => $node_name,
      'node_id'   => $node_id,
      'node_pw'   => $password,
    },
  }

  $config = deep_merge($generated_config, $config_overrides)

  file { dirname($config_file):
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { $config_file:
    ensure    => file,
    owner     => 'root',
    group     => 'root',
    mode      => '0640',
    show_diff => $password.empty,
    content   => stdlib::to_json_pretty($config),
  }

  # ---------------------------------------------------------------- service
  if $manage_service {
    $unit_file = "/etc/systemd/system/${service_name}.service"

    file { $unit_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('heplify/heplify.service.epp', {
          'bin_path'    => $bin_path,
          'config_file' => $config_file,
          'after_units' => $after_units,
      }),
    }

    exec { "${service_name}-daemon-reload":
      command     => 'systemctl daemon-reload',
      path        => ['/usr/bin', '/bin', '/usr/sbin', '/sbin'],
      refreshonly => true,
      subscribe   => File[$unit_file],
    }

    service { $service_name:
      ensure    => $service_ensure,
      enable    => $service_enable,
      require   => Exec["${service_name}-daemon-reload"],
      subscribe => [File[$config_file], File[$unit_file], $install_resource].filter |$r| { $r =~ NotUndef },
    }
  }
}
