# @summary Installs, configures and runs heplify-server, the HOMER HEP collector.
#
# heplify-server receives HEP from capture agents (such as the `heplify`
# class in this module) and from SIP servers that send HEP natively, and
# stores it in a database for the HOMER web UI. Every parameter has a
# default in the module's Hiera data.
#
# The defaults listen for HEP on UDP 0.0.0.0:9060 and store HOMER 7 data in
# a local PostgreSQL as the user `homer`. The module does not manage the
# database: create the `homer_data` and `homer_config` databases and the
# user beforehand (see the README).
#
# @example Collector with a local PostgreSQL
#   class { 'heplify::server':
#     db_password => Sensitive('change-me'),
#   }
#
# @example Change individual heplify-server settings from Hiera
#   heplify::server::db_password: 'change-me'
#   heplify::server::settings:
#     DBAddr: 'db.example.com:5432'
#     PromAddr: '127.0.0.1:9096'
#
# @param version
#   heplify-server release to install, for example `'1.60.1'`. With
#   `install_method => 'package'` this is the package version.
# @param install_method
#   `binary` downloads the release binary, `package` installs `package_name`
#   from a repository you manage, `none` leaves installation to you.
# @param download_base_url
#   Base URL for release binaries. The file fetched is
#   `<download_base_url>/v<version>/heplify-server` on amd64 and
#   `<download_base_url>/v<version>/heplify-server-arm64` on arm64.
# @param checksums
#   SHA-256 checksums of release binaries, keyed by version and then by
#   architecture (`amd64`, `arm64`). Merged across your Hiera hierarchy.
# @param checksum
#   SHA-256 checksum of the binary. Overrides the `checksums` entry for this
#   node. When neither is set the download is not verified.
# @param package_name
#   Package to install when `install_method` is `package`.
# @param install_dir
#   Directory holding the versioned binaries (`heplify-server-<version>`).
# @param bin_path
#   Path the service runs; a symlink to the current versioned binary when
#   `install_method` is `binary`.
# @param config_file
#   Path of the generated configuration. heplify-server only reads files
#   whose name contains `.toml`.
# @param manage_user
#   Create the system user and group the service runs as.
# @param user
#   User the service runs as.
# @param group
#   Group the service runs as; it can read the configuration file.
# @param settings
#   heplify-server settings written to `config_file`, keyed by their
#   heplify-server names (`HEPAddr`, `DBAddr`, `PromAddr`, ...). Deep-merged
#   across your Hiera hierarchy over the module defaults. Settings you leave
#   out take heplify-server's built-in defaults.
# @param db_password
#   Database password, written as `DBPass`. Converted to `Sensitive` on
#   lookup. When any password in the configuration is set, the file diff
#   is left out of reports.
# @param allow_db_superuser
#   heplify-server treats the database users `postgres`, `root` and `admin`
#   specially: it creates a `homer_user` with the fixed password
#   `homer_password` and, on PostgreSQL, grants it the `postgres` role.
#   Catalog compilation fails for those users unless this is `true`.
# @param manage_service
#   Manage the systemd unit and service.
# @param service_name
#   Name of the systemd service.
# @param service_ensure
#   Whether the service should be running or stopped.
# @param service_enable
#   Whether the service starts at boot.
# @param after_units
#   systemd units heplify-server is ordered after, in addition to
#   `network-online.target`. Units that do not exist are ignored by systemd.
class heplify::server (
  String[1]                                $version,
  Enum['binary', 'package', 'none']        $install_method,
  String[1]                                $download_base_url,
  Hash[String[1], Hash[Enum['amd64', 'arm64'], Heplify::Sha256]] $checksums,
  Optional[Heplify::Sha256]                $checksum,
  String[1]                                $package_name,
  Stdlib::Absolutepath                     $install_dir,
  Stdlib::Absolutepath                     $bin_path,
  Pattern[/\A\/.*\.toml\z/]                $config_file,
  Boolean                                  $manage_user,
  String[1]                                $user,
  String[1]                                $group,
  Hash[String[1], Heplify::ServerSetting]  $settings,
  Variant[String, Sensitive[String]]       $db_password,
  Boolean                                  $allow_db_superuser,
  Boolean                                  $manage_service,
  String[1]                                $service_name,
  Stdlib::Ensure::Service                  $service_ensure,
  Boolean                                  $service_enable,
  Array[String[1]]                         $after_units,
) {
  # heplify-server's own default database user is root.
  $db_user = $settings['DBUser'] ? {
    undef   => 'root',
    default => $settings['DBUser'],
  }
  if !$allow_db_superuser and $db_user in ['postgres', 'root', 'admin'] {
    $message = [
      "heplify::server: DBUser '${db_user}' makes heplify-server create a database user 'homer_user'",
      "with the password 'homer_password'. Use a dedicated database user, or set",
      'heplify::server::allow_db_superuser to true.',
    ].join(' ')
    fail($message)
  }

  contain heplify::server::install
  contain heplify::server::config
  contain heplify::server::service

  Class['heplify::server::install']
  -> Class['heplify::server::config']
  ~> Class['heplify::server::service']

  Class['heplify::server::install'] ~> Class['heplify::server::service']
}
