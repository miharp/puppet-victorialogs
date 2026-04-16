# @summary Rolling upgrade of VictoriaLogs across a set of targets
#
# Upgrades one node at a time. Each node is health-checked after apply before
# the plan advances to the next. The plan fails immediately if a node is
# unhealthy after upgrade, leaving remaining nodes on the old version.
#
# @example
#   bolt plan run victorialogs::upgrade --targets vlnodes version=1.50.0
#
# @param targets
# @param version
# @param edition
# @param service_name
#   Systemd service name to check after each upgrade.
# @param port
#   HTTP port for the /-/ready health check.
# @param force
#   Re-apply even if the target is already at $version. Default false.
plan victorialogs::upgrade (
  TargetSpec                $targets,
  String[1]                 $version,
  Enum['oss', 'enterprise'] $edition      = 'oss',
  String[1]                 $service_name = 'victorialogs-single',
  Integer                   $port         = 9428,
  Boolean                   $force        = false,
) {
  apply_prep($targets)

  $target_list = get_targets($targets)
  $results     = []

  $target_list.each |$target| {
    # Check installed version
    $iv = run_task('victorialogs::installed_version', $target).first
    $current = $iv['version']

    if !$force and $current == $version {
      out::message("${target.name}: already at ${version}, skipping")
      next()
    }

    out::message("${target.name}: upgrading ${current} → ${version}")

    apply($target) {
      class { 'victorialogs':
        version => $version,
        edition => $edition,
      }
    }

    $status = run_task('victorialogs::status', $target,
      service_name => $service_name,
      port         => $port,
    ).first

    unless $status['active'] and $status['ready'] {
      fail_plan("${target.name}: unhealthy after upgrade to ${version} — ${status['message']}. Halting rollout.")
    }

    out::message("${target.name}: healthy at ${version}")
  }

  out::message("Rolling upgrade to ${version} complete.")
}
