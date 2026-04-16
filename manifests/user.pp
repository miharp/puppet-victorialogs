# @summary Manages the VictoriaLogs system user, group, and home directory
# @api private
class victorialogs::user {
  assert_private()

  if $victorialogs::manage_group {
    group { $victorialogs::group:
      ensure => $victorialogs::ensure,
      system => true,
    }
  }

  if $victorialogs::manage_user {
    user { $victorialogs::user:
      ensure     => $victorialogs::ensure,
      comment    => 'VictoriaLogs service user',
      system     => true,
      gid        => $victorialogs::group,
      shell      => $victorialogs::shell,
      home       => $victorialogs::homedir,
      managehome => false,
    }
  }

  if $victorialogs::manage_homedir {
    file { $victorialogs::homedir:
      ensure => stdlib::ensure($victorialogs::ensure, 'directory'),
      mode   => $victorialogs::homedir_mode,
      owner  => $victorialogs::homedir_owner,
      group  => $victorialogs::homedir_group,
    }
  }
}
