# @summary Manages the heplify systemd unit and service.
#
# @api private
class heplify::service {
  assert_private()

  if $heplify::manage_service {
    $unit_file = "/etc/systemd/system/${heplify::service_name}.service"
    $unit_params = {
      'bin_path'    => $heplify::bin_path,
      'config_file' => "${heplify::config_dir}/heplify.json",
      'after_units' => $heplify::after_units,
    }

    file { $unit_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('heplify/heplify.service.epp', $unit_params),
    }

    exec { "${heplify::service_name}-systemctl-daemon-reload":
      command     => 'systemctl daemon-reload',
      path        => ['/usr/bin', '/bin', '/usr/sbin', '/sbin'],
      refreshonly => true,
      subscribe   => File[$unit_file],
    }

    service { $heplify::service_name:
      ensure    => $heplify::service_ensure,
      enable    => $heplify::service_enable,
      require   => Exec["${heplify::service_name}-systemctl-daemon-reload"],
      subscribe => File[$unit_file],
    }
  }
}
