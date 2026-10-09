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

This module installs and runs the two server-side pieces of the
[HOMER](https://sipcapture.org) VoIP monitoring platform:

* `heplify`: the [heplify](https://github.com/sipcapture/heplify) capture
  agent. It sniffs SIP (and optionally RTCP, RTP, DNS, LOG or Diameter) on a
  host and forwards it as HEP. Out of the box it captures SIP on ports
  5060-5090 on every interface and sends HEPv3 over UDP to `127.0.0.1:9060`.
* `heplify::server`: [heplify-server](https://github.com/sipcapture/heplify-server),
  the collector. It receives HEP from agents and from SIP servers that send HEP
  natively, and stores it in PostgreSQL for the HOMER web UI. Out of the box it
  listens on UDP `0.0.0.0:9060` and writes to a local PostgreSQL as `homer_user`.

Use either class on its own or both on one host. Every setting is a class
parameter with a default in the module's Hiera data, so you configure them
with `heplify::*` and `heplify::server::*` keys in your own Hiera.

The agent class targets heplify 2.x, which is configured with a JSON file
rather than command-line flags.

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

`heplify::server` manages:

* `/opt/heplify-server/heplify-server-<version>` and the
  `/usr/local/bin/heplify-server` symlink, installed the same way
* `/etc/heplify-server.toml`: the collector configuration, mode `0640`,
  readable by the service group
* the `heplify-server` system user and group
* `/etc/systemd/system/heplify-server.service`: runs heplify-server as that
  user, with `/var/log/heplify-server` as its working directory
* the `heplify-server` service

It does not manage PostgreSQL or the HOMER web UI (homer-app).

### Setup requirements

* [puppetlabs/stdlib](https://forge.puppet.com/modules/puppetlabs/stdlib):
  9.x on Puppet 7 (stdlib 10 requires Puppet 8), 9.x or 10.x on Puppet 8.
* systemd.
* An `x86_64`/`amd64` or `aarch64`/`arm64` node. Those are the only Linux
  architectures heplify publishes binaries for.
* For the default install method, nodes must reach
  `https://github.com/sipcapture/heplify/releases`, or a mirror you set in
  `heplify::download_base_url`.
* For the agent: a heplify-server that accepts HEP on the configured host,
  port and transport.
* For `heplify::server`: PostgreSQL 10 or later, with the `homer_data` and
  `homer_config` databases owned by a dedicated user (see
  [Run heplify-server](#run-heplify-server)). Nodes must reach
  `https://github.com/sipcapture/heplify-server/releases`, or a mirror you set
  in `heplify::server::download_base_url`.

### Beginning with heplify

On a SIP server whose traffic you want in HOMER, pointing at your HOMER host:

```puppet
class { 'heplify':
  hep_host => 'homer.example.com',
}
```

On the HOMER host, once the databases exist:

```puppet
include heplify::server
```

This connects as `homer_user` with the password `homer_password`, homer-app's
defaults. Set your own password in production (see
[Run heplify-server](#run-heplify-server)).

On a single host running both, `include heplify` needs no settings: the agent
already sends to `127.0.0.1:9060`.

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

`heplify::server::version`, `heplify::server::checksums` and
`heplify::server::checksum` work the same way for heplify-server. Its release
tags start with `v`, which the module adds: the binary is fetched from
`<download_base_url>/v<version>/heplify-server`, or `heplify-server-arm64` on
arm64.

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

### Relay HEP to several heplify-servers

FreeSWITCH, for example, can send HEP to only one capture server. To copy HEP
to several servers, run the agent as a relay on the sending host: turn packet
capture off, listen for HEP locally and list every destination. Each active
transport gets a copy; set `failover_only: true` on one to use it only when the
others are unreachable.

```yaml
heplify::config_overrides:
  socket:
    - name: default
      active: false
  collector_settings:
    active: true
    host: 127.0.0.1
    port: 9070
    proto: udp
  transport:
    - name: homer-a
      active: true
      protocol: HEPv3
      transport: udp
      host: 10.0.0.10
      port: 9060
    - name: homer-b
      active: true
      protocol: HEPv3
      transport: udp
      host: 10.0.0.20
      port: 9060
```

Then point the sender at `127.0.0.1:9070`.

### Run heplify-server

Create the databases first. heplify-server creates its tables, but not the
databases, and it needs to own them to create table partitions. With
[puppetlabs/postgresql](https://forge.puppet.com/modules/puppetlabs/postgresql):

```puppet
class { 'postgresql::server': }

postgresql::server::db { 'homer_data':
  user     => 'homer_user',
  password => Sensitive('homer_password'),
  owner    => 'homer_user',
}

postgresql::server::database { 'homer_config':
  owner => 'homer_user',
}

include heplify::server
Postgresql::Server::Db['homer_data'] -> Class['heplify::server']
```

Or by hand:

```sql
CREATE USER homer_user WITH PASSWORD 'homer_password';
CREATE DATABASE homer_data OWNER homer_user;
CREATE DATABASE homer_config OWNER homer_user;
```

`homer_user` and `homer_password` are homer-app's default credentials, so a
stock homer-app reads the same databases without changes. To use your own
password, change it in PostgreSQL, in homer-app and in Hiera.

Configure heplify-server from Hiera. `heplify::server::settings` uses
heplify-server's own setting names and is deep-merged over the module
defaults, so list only what you change. Keep the password in an encrypted
backend such as hiera-eyaml.

```yaml
heplify::server::db_password: >
  ENC[PKCS7,...]
heplify::server::settings:
  DBAddr: 'db.example.com:5432'
  DBDropDays: 30
  PromAddr: '127.0.0.1:9096'      # Prometheus metrics (off by default)
```

Set `settings` through Hiera rather than as a class parameter. A class
parameter replaces the whole hash, so the module defaults (database driver,
schema and user) would be lost.

Notes:

* Don't use `postgres`, `root` or `admin` as `DBUser`. heplify-server treats
  them as administrators: it creates `homer_user` itself and grants it the
  `postgres` role, which makes it a database superuser. The module refuses
  these users unless you set `heplify::server::allow_db_superuser: true`.
  Create `homer_user` yourself, as shown above, so it only owns the HOMER
  databases.
* heplify-server fills `homer_data`. The `homer_config` tables are created by
  homer-app, the HOMER 7 web UI, which you install separately.
* If heplify-server cannot parse its configuration file, it silently starts
  with built-in defaults (a HOMER 5 MySQL database as `root`). The module
  always generates valid TOML, but check `journalctl -u heplify-server` after
  hand edits.
* Logs go to the journal (`LogStd: true`). With `LogStd` and `LogSys` both
  `false`, heplify-server writes `heplify-server.log` to
  `/var/log/heplify-server` instead.
* The service runs unprivileged, so HEP listeners must use ports above 1023.

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
* `heplify::server` is tested with the HOMER 7 schema on PostgreSQL. It does
  not manage the database server or homer-app.

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
