# @summary Writes heplify.json from the class parameters.
#
# @api private
class heplify::config {
  assert_private()

  $password = $heplify::hep_password ? {
    Sensitive => $heplify::hep_password.unwrap,
    default   => $heplify::hep_password,
  }

  # heplify builds its kernel BPF filter from every entry in "protocol", so
  # only the captured protocols are listed. An RTP/RTCP entry (1024-65535) on
  # a SIP-only agent would pull nearly all UDP into userspace, including the
  # agent's own HEP packets on loopback. Ranges match heplify's own defaults.
  $protocol_defs = {
    'SIP'      => { 'min_port' => $heplify::sip_port_min, 'max_port' => $heplify::sip_port_max, 'protocol' => ['udp', 'tcp'] },
    'RTCP'     => { 'min_port' => 1024, 'max_port' => 65535, 'protocol' => ['udp'] },
    'RTP'      => { 'min_port' => 1024, 'max_port' => 65535, 'protocol' => ['udp'] },
    'DNS'      => { 'min_port' => 53,   'max_port' => 53,    'protocol' => ['udp', 'tcp'] },
    'DIAMETER' => { 'min_port' => 3868, 'max_port' => 3868,  'protocol' => ['tcp', 'sctp'] },
  }
  $protocols = $heplify::capture_mode.unique.filter |$mode| { $mode in $protocol_defs }.map |$mode| {
    { 'name' => $mode, 'description' => $mode } + $protocol_defs[$mode]
  }

  $generated = {
    'socket'          => [
      {
        'name'              => 'default',
        'active'            => true,
        'socket_type'       => $heplify::socket_type,
        'transport_profile' => ['hep'],
        'device'            => $heplify::interface,
        'promisc'           => $heplify::promisc,
        'tcp_reasm'         => $heplify::tcp_reassembly,
        'sip_reasm'         => $heplify::sip_reassembly,
        'ipfragments'       => $heplify::ip_defrag,
        'vlan'              => $heplify::vlan,
        'snap_len'          => 8192,
        'capture_mode'      => $heplify::capture_mode,
        'bpf_filter'        => $heplify::bpf_filter,
      },
    ],
    'transport'       => [
      {
        'name'      => 'hep',
        'active'    => true,
        'protocol'  => 'HEPv3',
        'host'      => $heplify::hep_host,
        'port'      => $heplify::hep_port,
        'transport' => $heplify::hep_transport,
        'password'  => $password,
      },
    ],
    'protocol'        => $protocols,
    'log_settings'    => {
      'active' => true,
      'level'  => $heplify::log_level,
      'stdout' => true,
      'json'   => false,
    },
    'sip_settings'    => {
      'discard_methods' => $heplify::discard_methods,
      'deduplicate'     => $heplify::deduplicate,
    },
    'hep_settings'    => {
      'deduplicate' => $heplify::deduplicate,
    },
    'rtcp_settings'   => {
      'active' => 'RTCP' in $heplify::capture_mode,
    },
    'system_settings' => {
      'node_name' => $heplify::node_name,
      'node_id'   => $heplify::node_id,
      'node_pw'   => $password,
    },
  }

  file { $heplify::config_dir:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { "${heplify::config_dir}/heplify.json":
    ensure    => file,
    owner     => 'root',
    group     => 'root',
    mode      => '0640',
    show_diff => $password.empty,
    content   => stdlib::to_json_pretty(heplify::deep_merge($generated, $heplify::config_overrides)),
  }
}
