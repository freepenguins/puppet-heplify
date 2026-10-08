# Run heplify-server against a local PostgreSQL that already has the
# homer_data and homer_config databases owned by the user homer.
class { 'heplify::server':
  db_password => Sensitive('change-me'),
}
