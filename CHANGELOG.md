# Changelog

All notable changes to this project will be documented in this file.

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

**Bugfixes**

**Known Issues**

* Upstream publishes no checksum files; the shipped checksums were computed
  from the GitHub release assets.
