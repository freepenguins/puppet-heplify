# @summary Manages the heplify-server systemd unit and service.
#
# @api private
class heplify::server::service {
  assert_private()

  if $heplify::server::manage_service {
    $unit_file = "/etc/systemd/system/${heplify::server::service_name}.service"
    $unit_params = {
      'bin_path'    => $heplify::server::bin_path,
      'config_file' => $heplify::server::config_file,
      'user'        => $heplify::server::user,
      'group'       => $heplify::server::group,
      'after_units' => $heplify::server::after_units,
    }

    file { $unit_file:
      ensure  => file,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => epp('heplify/heplify-server.service.epp', $unit_params),
    }

    exec { "${heplify::server::service_name}-systemctl-daemon-reload":
      command     => 'systemctl daemon-reload',
      path        => ['/usr/bin', '/bin', '/usr/sbin', '/sbin'],
      refreshonly => true,
      subscribe   => File[$unit_file],
    }

    service { $heplify::server::service_name:
      ensure    => $heplify::server::service_ensure,
      enable    => $heplify::server::service_enable,
      require   => Exec["${heplify::server::service_name}-systemctl-daemon-reload"],
      subscribe => File[$unit_file],
    }
  }
}
