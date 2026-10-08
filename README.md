# heplify Puppet module (Hiera-driven)

Installs the HOMER [heplify](https://github.com/sipcapture/heplify) v2 capture
agent, writes `/etc/heplify/heplify.json` and runs it under systemd. Defaults:
capture SIP (ports 5060-5090) on all interfaces and send HEPv3 over UDP to a
heplify-server on the same host, `127.0.0.1:9060`.

## Layout

    modules/heplify/                 the module (copy into your modulepath)
      manifests/init.pp              class heplify
      templates/heplify.service.epp  systemd unit
      data/common.yaml               every default, as Hiera keys
      hiera.yaml                     module data layer
    control-repo-example/            how to drive it from your own Hiera
      data/common.yaml               site-wide settings + version/checksum pin
      data/nodes/<certname>.yaml     per-node overrides

Works on Puppet 7 and 8. Requires `puppetlabs-stdlib` >= 9: use stdlib 9.x on
Puppet 7 (stdlib 10 needs Puppet 8), either 9.x or 10.x on Puppet 8.

## Use

1. Copy `modules/heplify` into your control repo and add
   `mod 'puppetlabs-stdlib'` to the Puppetfile if it is not there already.
2. `include heplify` on the node (or add `heplify` to a Hiera `classes` array).
3. Override `heplify::*` keys in Hiera. The full list with defaults is in
   `modules/heplify/data/common.yaml`.

Keys without a dedicated parameter go under `heplify::config_overrides`, which
is deep-merged across your hierarchy and then over the generated JSON. Arrays
(`socket`, `transport`, `protocol`) are replaced whole, not merged.

## Notes

- heplify-server must listen for HEP on UDP 9060 (its default `HEPAddr`). For
  TCP, set `HEPTCPAddr` on the server and `heplify::hep_transport: tcp` plus
  the matching `heplify::hep_port` here.
- With `interface: any`, a packet that crosses a bridge, bond or loopback is
  captured once per interface. Either pin `heplify::interface` to one NIC or
  set `heplify::deduplicate: true` (which also hides genuine retransmissions).
- Adding `RTCP` or `RTP` to `heplify::capture_mode` widens the kernel filter
  to UDP 1024-65535.
- Upgrade by changing `heplify::version` and `heplify::checksum` together.
