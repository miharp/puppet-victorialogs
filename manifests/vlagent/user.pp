# @summary Manages the vlagent system user and group
# @api private
class victorialogs::vlagent::user {
  assert_private()

  if $victorialogs::vlagent::manage_group {
    group { $victorialogs::vlagent::group:
      ensure => $victorialogs::vlagent::ensure,
      system => true,
    }
  }

  if $victorialogs::vlagent::manage_user {
    user { $victorialogs::vlagent::user:
      ensure     => $victorialogs::vlagent::ensure,
      comment    => 'vlagent service user',
      system     => true,
      gid        => $victorialogs::vlagent::group,
      shell      => $victorialogs::vlagent::shell,
      managehome => false,
    }
  }
}
