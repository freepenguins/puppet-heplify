# heplify

## Table of Contents

1. [Description](#description)
1. [Setup - The basics of getting started with heplify](#setup)
    * [What heplify affects](#what-heplify-affects)
    * [Setup requirements](#setup-requirements)
    * [Beginning with heplify](#beginning-with-heplify)
1. [Usage - Configuration options and additional functionality](#usage)
1. [Reference](#reference)
1. [Limitations - OS compatibility, etc.](#limitations)
1. [Development - Guide for contributing to the module](#development)

## Description

This module installs and runs [heplify](https://github.com/sipcapture/heplify),
the capture agent for the [HOMER](https://sipcapture.org) VoIP monitoring
platform. heplify sniffs SIP (and optionally RTCP, RTP, DNS, LOG or Diameter)
on a host and forwards it as HEP to a heplify-server.

Every setting is a class parameter with a default in the module's Hiera data,
so you configure the agent with `heplify::*` keys in your own Hiera. Out of the
box it captures SIP on ports 5060-5090 on every interface and sends HEPv3 over
UDP to a heplify-server on the same host (`127.0.0.1:9060`, heplify-server's
default listener).

The module targets heplify 2.x, which is configured with a JSON file rather
than command-line flags.

## Setup

### What heplify affects

* `/opt/heplify/heplify-<version>`: the release binary, downloaded from GitHub
  and verified against a SHA-256 checksum
* `/usr/local/bin/heplify`: a symlink to the current version, so upgrades and
  rollbacks only change the link
* `/etc/heplify/heplify.json`: the agent configuration, mode `0640`
* `/etc/systemd/system/heplify.service`: a systemd unit that runs heplify as
  root with only the `CAP_NET_RAW` and `CAP_NET_ADMIN` capabilities
* the `heplify` service

With `install_method: package` the module installs a `heplify` package instead
of the binary; with `install_method: none` it leaves installation to you.

### Setup requirements

* [puppetlabs/stdlib](https://forge.puppet.com/modules/puppetlabs/stdlib):
  9.x on Puppet 7 (stdlib 10 requires Puppet 8), 9.x or 10.x on Puppet 8.
* systemd.
* An `x86_64`/`amd64` or `aarch64`/`arm64` node. Those are the only Linux
  architectures heplify publishes binaries for.
* For the default install method, nodes must reach
  `https://github.com/sipcapture/heplify/releases`, or a mirror you set in
  `heplify::download_base_url`.
* A heplify-server that accepts HEP on the configured host, port and
  transport.

### Beginning with heplify

On a host that also runs heplify-server with its default settings:

```puppet
include heplify
```

## Usage

### Configure from Hiera

All parameters resolve through Hiera, so a typical setup is one class include
plus data. Only list the keys you want to change; the full set of defaults is
in [`data/common.yaml`](data/common.yaml).

```yaml
# data/common.yaml in your control repository
heplify::capture_mode:
  - SIP
heplify::hep_host: homer.example.com
heplify::hep_port: 9060
heplify::hep_transport: udp
```

If your control repository assigns classes from Hiera rather than from node
definitions, a common pattern is:

```puppet
# manifests/site.pp
node default {
  lookup('classes', Array[String], 'unique', []).include
}
```

```yaml
# data/common.yaml
classes:
  - heplify
```

### Per-node settings

Per-node data overrides the site-wide data. For example, in
`data/nodes/sip01.example.com.yaml`:

```yaml
# Capture on one NIC instead of all of them. This avoids seeing the same
# packet twice on bridged or bonded hosts.
heplify::interface: eth0

# Non-standard SIP ports on this host.
heplify::sip_port_min: 5060
heplify::sip_port_max: 5080

# Keep keepalive noise out of HOMER.
heplify::discard_methods:
  - OPTIONS

heplify::node_name: sip01
heplify::node_id: 2101
```

### Send to a remote heplify-server over TCP

heplify-server listens for UDP HEP on `HEPAddr` by default. For TCP, set
`HEPTCPAddr` on the server, then:

```puppet
class { 'heplify':
  hep_host      => 'homer.example.com',
  hep_port      => 9061,
  hep_transport => 'tcp',
}
```

### Use a HEP password

`heplify::hep_password` is converted to `Sensitive` on lookup. When it is set,
the config file diff is left out of Puppet reports. Keep the value in an
encrypted Hiera backend such as hiera-eyaml:

```yaml
heplify::hep_password: >
  ENC[PKCS7,...]
```

### Capture RTCP as well as SIP

```yaml
heplify::capture_mode:
  - SIP
  - RTCP
```

Each protocol in `capture_mode` widens the kernel capture filter. RTCP and RTP
use UDP 1024-65535, which on a busy host is most UDP traffic. When the
heplify-server runs on the same host, pin `heplify::interface` to the external
NIC so the agent does not also inspect its own HEP traffic on loopback.

### Settings without a parameter

Anything in `heplify.json` that has no dedicated parameter goes in
`heplify::config_overrides`, which is deep-merged over the generated
configuration (and across your Hiera hierarchy). Arrays such as `socket`,
`transport` and `protocol` are replaced whole. For example, to expose
Prometheus metrics on localhost:

```yaml
heplify::config_overrides:
  prometheus_settings:
    active: true
    host: 127.0.0.1
    port: 9096
```

See the [heplify configuration reference](https://github.com/sipcapture/heplify)
for the available keys.

### Upgrade heplify

Upstream does not publish checksum files, so the module ships SHA-256 sums for
the releases it has been tested with in `heplify::checksums`. To deploy a newer
release, add its checksums for the architectures you run. Your entries are
merged with the module's.

```yaml
heplify::version: '2.0.29'
heplify::checksums:
  '2.0.29':
    amd64: '<sha256 of heplify_linux_amd64>'
    arm64: '<sha256 of heplify_linux_arm64>'
```

Compute each value with `sha256sum` on a copy of the release asset you trust.
For one-off cases, `heplify::checksum` overrides the lookup for a single node.
If neither is set for a version, the binary is downloaded without verification.

### Install from a mirror or a package

```yaml
# Fetch <mirror>/<version>/heplify_linux_<arch> instead of GitHub
heplify::download_base_url: 'https://artifacts.example.com/heplify'
```

```yaml
# Install the "heplify" package from a repository you already manage
heplify::install_method: package
heplify::version: '2.0.28'
```

## Reference

[REFERENCE.md](REFERENCE.md) documents every parameter and its data type.
Defaults live in the module's Hiera data, [`data/common.yaml`](data/common.yaml),
rather than in the class.

## Limitations

* Linux with systemd only, on `amd64` and `arm64`.
* Supports heplify 2.x. heplify 1.x used command-line flags and is not
  supported.
* With `interface: any`, a packet that crosses a bridge, bond or loopback is
  captured once per interface. Pin `heplify::interface` or set
  `heplify::deduplicate: true`. Deduplication also hides genuine SIP
  retransmissions.
* The module manages one capture socket and one HEP destination. For fan-out
  or failover destinations, replace the `transport` and `socket` arrays through
  `heplify::config_overrides`.
* On Puppet 7, use puppetlabs/stdlib 9.x.

## Development

This module was created from the
[PDK templates](https://github.com/puppetlabs/pdk-templates). Run the usual PDK
commands from the module root:

```shell
pdk validate
pdk test unit
pdk build
```

The module is pinned to pdk-templates 3.8.0 (`template-url` in
`metadata.json`). Its Gemfile installs Puppet from the public rubygems.org
unless `PUPPET_FORGE_TOKEN` is set, in which case it uses the Puppet Core gem
source. pdk-templates 4.x makes Puppet Core the default, and its only opt-out
is a Bundler setting that PDK ignores, so `pdk validate` cannot use public gems
with those templates. Keep the pin unless you have Puppet Core credentials.

To test against a specific Puppet version without PDK:

```shell
PUPPET_GEM_VERSION='~> 7' bundle exec rake spec
PUPPET_GEM_VERSION='~> 8' bundle exec rake spec
```

The unit tests run against every operating system in `metadata.json`,
including the `aarch64` fact sets, which cover the arm64 binary.

Regenerate `REFERENCE.md` after changing parameters or their documentation:

```shell
pdk bundle exec puppet strings generate --format markdown --out REFERENCE.md
```

Bug reports and pull requests are welcome at
<https://github.com/freepenguins/puppet-heplify>.
