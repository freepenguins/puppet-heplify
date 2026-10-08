# @summary Writes the heplify-server TOML configuration.
#
# @api private
class heplify::server::config {
  assert_private()

  $password = $heplify::server::db_password ? {
    Sensitive => $heplify::server::db_password.unwrap,
    default   => $heplify::server::db_password,
  }
  $password_setting = $password.empty ? {
    true    => {},
    default => { 'DBPass' => $password },
  }
  $settings = $heplify::server::settings + $password_setting

  # Keep passwords (DBPass, ESPass, ConfigHTTPPW, ...) out of reports.
  $secrets = $settings.filter |$key, $value| { $key =~ /(Pass|PW)\z/ and $value =~ String[1] }

  # heplify-server silently falls back to its built-in defaults when the
  # file is not valid TOML, so it is always generated, never templated.
  file { $heplify::server::config_file:
    ensure    => file,
    owner     => 'root',
    group     => $heplify::server::group,
    mode      => '0640',
    show_diff => $secrets.empty,
    content   => stdlib::to_toml($settings),
  }
}
