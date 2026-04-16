# @summary Bootstrap a VictoriaLogs cluster
#
# Applies nodes in dependency order: storage first, then insert and select nodes
# (with storage addresses wired in). Fails fast if storage nodes are unhealthy
# before proceeding to insert/select.
#
# @example
#   bolt plan run victorialogs::cluster \
#     storage_targets=vlstorage-01,vlstorage-02,vlstorage-03 \
#     insert_targets=vlinsert-01,vlinsert-02 \
#     select_targets=vlselect-01,vlselect-02 \
#     version=1.49.0
#
# @param storage_targets
# @param insert_targets
# @param select_targets
# @param version
# @param edition
# @param install_method
# @param storage_port
#   Port VictoriaLogs storage nodes listen on (used to build -storageNode flag values).
plan victorialogs::cluster (
  TargetSpec                         $storage_targets,
  TargetSpec                         $insert_targets,
  TargetSpec                         $select_targets,
  String[1]                          $version,
  Enum['oss', 'enterprise']          $edition        = 'oss',
  Enum['archive', 'package', 'none'] $install_method = 'archive',
  Integer                            $storage_port   = 9428,
) {
  # 1. Prepare all targets (gather facts needed for catalog compilation)
  apply_prep([$storage_targets, $insert_targets, $select_targets])

  # 2. Apply storage nodes
  out::message('Applying storage nodes...')
  apply($storage_targets) {
    class { 'victorialogs':
      version        => $version,
      edition        => $edition,
      install_method => $install_method,
    }
  }

  # 3. Health-check storage before proceeding
  $storage_status = run_task('victorialogs::status', $storage_targets,
    service_name => 'victorialogs-single',
    port         => $storage_port,
  )
  $storage_failed = $storage_status.filter |$r| { !$r['active'] or !$r['ready'] }
  unless $storage_failed.empty {
    fail_plan("Storage nodes unhealthy, aborting cluster bootstrap: ${storage_failed.map |$r| { $r.target.name }.join(', ')}")
  }

  # 4. Build the storageNode flag value from storage target hostnames
  $storage_addrs = get_targets($storage_targets).map |$t| {
    "${t.host}:${storage_port}"
  }.join(',')

  # 5. Apply insert nodes
  out::message("Applying insert nodes (storageNode=${storage_addrs})…")
  apply($insert_targets) {
    class { 'victorialogs':
      version        => $version,
      edition        => $edition,
      install_method => $install_method,
      instances      => {
        insert => {
          options => {
            common => {
              '-storageNode'    => $storage_addrs,
              '-select.disable' => true,
            },
          },
        },
      },
    }
  }

  # 6. Apply select nodes
  out::message("Applying select nodes (storageNode=${storage_addrs})…")
  apply($select_targets) {
    class { 'victorialogs':
      version        => $version,
      edition        => $edition,
      install_method => $install_method,
      instances      => {
        select => {
          options => {
            common => {
              '-storageNode'    => $storage_addrs,
              '-insert.disable' => true,
            },
          },
        },
      },
    }
  }

  # 7. Final health check across all nodes
  $all_targets = get_targets($storage_targets) + get_targets($insert_targets) + get_targets($select_targets)
  $final_status = run_task('victorialogs::status', $all_targets,
    service_name => 'victorialogs-single',
    port         => $storage_port,
  )
  $final_failed = $final_status.filter |$r| { !$r['active'] or !$r['ready'] }
  unless $final_failed.empty {
    fail_plan("Cluster bootstrap complete but some nodes unhealthy: ${$final_failed.map |$r| { $r.target.name }.join(', ')}")
  }

  out::message('Cluster bootstrap complete. All nodes healthy.')
  return $final_status
}
