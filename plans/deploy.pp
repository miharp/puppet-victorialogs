# @summary Deploy VictoriaLogs to one or more targets
#
# Resolves the latest version automatically when $version is not specified,
# applies the Puppet catalog, then runs a smoke test.
#
# @example Deploy latest version to a single node
#   bolt plan run victorialogs::deploy --targets vlnode-01
#
# @example Deploy a specific version
#   bolt plan run victorialogs::deploy --targets vlnode-01 version=1.49.0
#
# @example Deploy with custom options (Hiera is preferred for complex configs)
#   bolt plan run victorialogs::deploy --targets vlnode-01 version=1.49.0
#
# @param targets
# @param version
#   Version to deploy. Omit to resolve the latest release from GitHub.
# @param edition
# @param install_method
# @param service_name
#   Systemd service name to health-check after apply (default: victorialogs-single).
# @param port
#   HTTP port for the /-/ready health check.
plan victorialogs::deploy (
  TargetSpec                         $targets,
  Optional[String[1]]                $version        = undef,
  Enum['oss', 'enterprise']          $edition        = 'oss',
  Enum['archive', 'package', 'none'] $install_method = 'archive',
  String[1]                          $service_name   = 'victorialogs-single',
  Integer                            $port           = 9428,
) {
  # Resolve version if not pinned
  if $version =~ Undef {
    $result = run_task('victorialogs::latest_version', 'localhost')
    $real_version = $result.first['version']
  } else {
    $real_version = $version
  }

  out::message("Deploying VictoriaLogs ${real_version} (${edition}) to ${targets}")

  apply_prep($targets)

  apply($targets) {
    class { 'victorialogs':
      version        => $real_version,
      edition        => $edition,
      install_method => $install_method,
    }
  }

  $status = run_task('victorialogs::status', $targets,
    service_name => $service_name,
    port         => $port,
  )

  $failed = $status.filter |$r| { !$r['active'] or !$r['ready'] }
  unless $failed.empty {
    fail_plan("Health check failed on: ${failed.map |$r| { $r.target.name }.join(', ')}")
  }

  out::message('Deploy complete. All targets healthy.')
  return $status
}
