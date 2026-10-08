# @summary Installs heplify-server and its service account.
#
# @api private
class heplify::server::install {
  assert_private()

  if $heplify::server::manage_user {
    group { $heplify::server::group:
      ensure => present,
      system => true,
    }

    user { $heplify::server::user:
      ensure     => present,
      system     => true,
      gid        => $heplify::server::group,
      home       => '/nonexistent',
      managehome => false,
      shell      => '/usr/sbin/nologin',
      comment    => 'heplify-server',
      require    => Group[$heplify::server::group],
    }
  }

  case $heplify::server::install_method {
    'binary': {
      $arch = heplify::release_arch($facts['os']['architecture'], 'heplify::server')
      $asset = $arch ? {
        'arm64' => 'heplify-server-arm64',
        default => 'heplify-server',
      }

      $checksum = $heplify::server::checksum ? {
        undef   => $heplify::server::checksums.dig($heplify::server::version, $arch),
        default => $heplify::server::checksum,
      }
      $checksum_attrs = $checksum ? {
        undef   => {},
        default => { 'checksum' => 'sha256', 'checksum_value' => $checksum },
      }

      $versioned_bin = "${heplify::server::install_dir}/heplify-server-${heplify::server::version}"

      file { $heplify::server::install_dir:
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
        source => "${heplify::server::download_base_url}/v${heplify::server::version}/${asset}",
        *      => $checksum_attrs,
      }

      # Upgrades and rollbacks are a symlink change; older binaries stay on disk.
      file { $heplify::server::bin_path:
        ensure => link,
        target => $versioned_bin,
      }
    }
    'package': {
      package { $heplify::server::package_name:
        ensure => $heplify::server::version,
      }
    }
    default: {
      # install_method 'none': installation is handled outside this module.
    }
  }
}
