# @summary Installs, configures and runs the HOMER heplify HEP capture agent.
#
# heplify captures VoIP signalling (SIP, and optionally RTCP, RTP, DNS, LOG
# or Diameter) and forwards it as HEP to a HOMER heplify-server. Every
# parameter has a default in the module's Hiera data, so the usual way to
# configure the agent is with `heplify::*` keys in your own Hiera.
#
# The defaults capture SIP on ports 5060-5090 on every interface and send
# HEPv3 over UDP to a heplify-server on the same host (127.0.0.1:9060).
#
# @example Capture SIP and send it to a heplify-server on the same host
#   include heplify
#
# @example Send to a remote heplify-server over TCP from a single interface
#   class { 'heplify':
#     interface     => 'eth0',
#     hep_host      => 'homer.example.com',
#     hep_port      => 9061,
#     hep_transport => 'tcp',
#   }
#
# @param version
#   heplify release to install, for example `'2.0.28'`. With
#   `install_method => 'package'` this is the package version.
# @param install_method
#   `binary` downloads the release binary, `package` installs `package_name`
#   from a repository you manage, `none` leaves installation to you.
# @param download_base_url
#   Base URL for release binaries. The file fetched is
#   `<download_base_url>/<version>/heplify_linux_<amd64|arm64>`. Point it at
#   an internal mirror if nodes cannot reach GitHub.
# @param checksums
#   SHA-256 checksums of release binaries, keyed by version and then by
#   architecture (`amd64`, `arm64`). Merged across your Hiera hierarchy, so
#   adding a new version does not drop the ones shipped with the module.
# @param checksum
#   SHA-256 checksum of the binary. Overrides the `checksums` entry for this
#   node. When neither is set the download is not verified.
# @param package_name
#   Package to install when `install_method` is `package`.
# @param install_dir
#   Directory holding the versioned binaries (`heplify-<version>`).
# @param bin_path
#   Path the service runs; a symlink to the current versioned binary when
#   `install_method` is `binary`.
# @param config_dir
#   Directory for `heplify.json`.
# @param interface
#   Capture device, for example `any` or `eth0`.
# @param socket_type
#   Capture method: `afpacket` or `pcap`.
# @param promisc
#   Put the interface into promiscuous mode.
# @param capture_mode
#   Protocols to capture. Each one widens the kernel capture filter, so
#   list only what you need.
# @param sip_port_min
#   Lowest SIP port to capture.
# @param sip_port_max
#   Highest SIP port to capture.
# @param tcp_reassembly
#   Reassemble TCP streams, needed for SIP over TCP.
# @param sip_reassembly
#   Reassemble SIP messages split across TCP segments.
# @param ip_defrag
#   Reassemble fragmented IP packets.
# @param vlan
#   Capture VLAN-tagged traffic.
# @param bpf_filter
#   Custom BPF filter. Empty means heplify builds one from the capture
#   protocols and ports.
# @param hep_host
#   Address of the heplify-server.
# @param hep_port
#   HEP port on the heplify-server.
# @param hep_transport
#   Transport to the heplify-server: `udp`, `tcp` or `tls`.
# @param hep_password
#   HEP node password, if the heplify-server requires one. The config file
#   diff is hidden from reports when this is set.
# @param node_name
#   HEP node name reported to HOMER.
# @param node_id
#   HEP node ID reported to HOMER.
# @param deduplicate
#   Drop duplicate packets, for example when `interface` is `any` and
#   traffic crosses a bridge. Also hides genuine retransmissions.
# @param discard_methods
#   SIP methods to drop before sending, for example `['OPTIONS']`.
# @param log_level
#   heplify log level.
# @param config_overrides
#   Hash deep-merged over the generated `heplify.json`, for any heplify
#   setting without a dedicated parameter. Arrays are replaced, not merged.
# @param manage_service
#   Manage the systemd unit and service.
# @param service_name
#   Name of the systemd service.
# @param service_ensure
#   Whether the service should be running or stopped.
# @param service_enable
#   Whether the service starts at boot.
# @param after_units
#   systemd units heplify is ordered after, in addition to
#   `network-online.target`. Units that do not exist are ignored by systemd.
class heplify (
  String[1]                                $version,
  Enum['binary', 'package', 'none']        $install_method,
  String[1]                                $download_base_url,
  Hash[String[1], Hash[Enum['amd64', 'arm64'], Heplify::Sha256]] $checksums,
  Optional[Heplify::Sha256]                $checksum,
  String[1]                                $package_name,
  Stdlib::Absolutepath                     $install_dir,
  Stdlib::Absolutepath                     $bin_path,
  Stdlib::Absolutepath                     $config_dir,
  String[1]                                $interface,
  Enum['afpacket', 'pcap']                 $socket_type,
  Boolean                                  $promisc,
  Array[Heplify::CaptureMode, 1]           $capture_mode,
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

  contain heplify::install
  contain heplify::config
  contain heplify::service

  Class['heplify::install']
  -> Class['heplify::config']
  ~> Class['heplify::service']

  Class['heplify::install'] ~> Class['heplify::service']
}
