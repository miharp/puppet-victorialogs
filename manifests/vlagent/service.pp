# @summary Manages the vlagent systemd service
# @api private
class victorialogs::vlagent::service {
  assert_private()

  $real_service_active = $victorialogs::vlagent::ensure ? {
    'absent' => false,
    default  => $victorialogs::vlagent::service_active,
  }

  $real_service_enable = $victorialogs::vlagent::ensure ? {
    'absent' => false,
    default  => $victorialogs::vlagent::service_enable,
  }

  # Build flat flag list from service_args hash.
  # Boolean true  => bare flag; Boolean false => flag omitted.
  $args = $victorialogs::vlagent::service_args.reduce([]) |$memo, $pair| {
    $k = $pair[0]
    $v = $pair[1]
    $v ? {
      false   => $memo,
      true    => $memo + [$k],
      default => $memo + ["${k}=${v}"],
    }
  }

  # Append enterprise license flags if configured
  $license_args = $victorialogs::vlagent::enterprise_license_key ? {
    undef   => [],
    default => ["-license=${victorialogs::vlagent::enterprise_license_key}"],
  }
  $license_file_args = $victorialogs::vlagent::enterprise_license_key_file ? {
    undef   => [],
    default => ["-licenseFile=${victorialogs::vlagent::enterprise_license_key_file}"],
  }

  $all_args = $args + $license_args + $license_file_args

  systemd::unit_file { "${victorialogs::vlagent::service_name}.service":
    ensure  => $victorialogs::vlagent::ensure,
    active  => $real_service_active,
    enable  => $real_service_enable,
    content => epp('victorialogs/vlagent.service.epp', {
      service_name => $victorialogs::vlagent::service_name,
      user         => $victorialogs::vlagent::user,
      group        => $victorialogs::vlagent::group,
      binary_path  => $victorialogs::vlagent::install::binary_path,
      args         => $all_args,
      limit_nofile => $victorialogs::vlagent::limit_nofile,
    }),
  }
}
