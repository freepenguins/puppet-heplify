# @summary Installs the heplify binary or package.
#
# @api private
class heplify::install {
  assert_private()

  case $heplify::install_method {
    'binary': {
      $arch = heplify::release_arch($facts['os']['architecture'], 'heplify')

      $checksum = $heplify::checksum ? {
        undef   => $heplify::checksums.dig($heplify::version, $arch),
        default => $heplify::checksum,
      }
      $checksum_attrs = $checksum ? {
        undef   => {},
        default => { 'checksum' => 'sha256', 'checksum_value' => $checksum },
      }

      $versioned_bin = "${heplify::install_dir}/heplify-${heplify::version}"

      file { $heplify::install_dir:
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
        source => "${heplify::download_base_url}/${heplify::version}/heplify_linux_${arch}",
        *      => $checksum_attrs,
      }

      # Upgrades and rollbacks are a symlink change; older binaries stay on disk.
      file { $heplify::bin_path:
        ensure => link,
        target => $versioned_bin,
      }
    }
    'package': {
      package { $heplify::package_name:
        ensure => $heplify::version,
      }
    }
    default: {
      # install_method 'none': installation is handled outside this module.
    }
  }
}
