# Changelog

All notable changes to this project will be documented in this file.

## Release 0.3.0

**Features**

* heplify-server now defaults to homer-app's database credentials:
  `DBUser` is `homer_user` (was `homer`) and `heplify::server::db_password`
  is `homer_password` (was empty). Override the password in production.
  If you created the user as `homer`, either rename it
  (`ALTER ROLE homer RENAME TO homer_user;`, then set its password again,
  because renaming clears an MD5 password) or keep the old name with:

  ```yaml
  heplify::server::settings:
    DBUser: homer
  ```

**Bugfixes**

**Known Issues**

## Release 0.2.0

**Features**

* New `heplify::server` class that installs, configures and runs
  heplify-server, the HOMER HEP collector. It downloads the release binary for
  `amd64` or `arm64`, verified against SHA-256 checksums for 1.60.1 shipped in
  the module's Hiera data, or installs a package. It writes
  `/etc/heplify-server.toml` from `heplify::server::settings`, deep-merged
  across Hiera, and runs the service as an unprivileged system user.
* Refuses database users that make heplify-server create a `homer_user` with a
  fixed password, unless `allow_db_superuser` is set.
* README examples for relaying HEP to several heplify-servers and for creating
  the HOMER databases with puppetlabs/postgresql.

**Bugfixes**

**Known Issues**

* The heplify-server 1.60.1 release binary reports its version as 1.60.2.

## Release 0.1.0

**Features**

* Installs the heplify 2.x release binary for `amd64` or `arm64`, verified
  against SHA-256 checksums shipped in the module's Hiera data (heplify
  2.0.28), with optional package or unmanaged installation.
* Generates `heplify.json` from class parameters, with
  `config_overrides` for any other heplify setting.
* Builds the capture protocol list from `capture_mode` only, so the kernel
  capture filter stays as narrow as the protocols you capture.
* Runs heplify under a systemd unit limited to `CAP_NET_RAW` and
  `CAP_NET_ADMIN`.
* Supports Puppet 7 and 8 on Debian, Ubuntu, RedHat, Rocky and AlmaLinux.
* Module Hiera data can be set per distro codename
  (`data/os/<os.name>/<codename>.yaml`).
* Pinned to pdk-templates 3.8.0, so `pdk validate` and `pdk test unit` work
  without Puppet Core credentials.

**Bugfixes**

**Known Issues**

* Upstream publishes no checksum files; the shipped checksums were computed
  from the GitHub release assets.
