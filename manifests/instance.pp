# @summary Manages a single VictoriaLogs instance as a systemd service
#
# Each instance corresponds to one `victoria-logs-prod` process with its own
# systemd unit file. Multiple instances can run on a single host (e.g. for
# cluster roles or isolated tenants).
#
# @example Single-node instance with a syslog input
#   victorialogs::instance { 'primary':
#     options => {
#       common => {
#         '-storageDataPath' => '/var/lib/victorialogs/data',
#       },
#       syslog => {
#         '-syslog.listenAddr.tcp' => ':514',
#         '-syslog.tenantID.tcp'   => '0:0',
#       },
#     },
#   }
#
# @example Cluster insert node (disable select, point at storage nodes)
#   victorialogs::instance { 'insert':
#     options => {
#       common => {
#         '-storageNode'    => 'vlstorage-01:9428,vlstorage-02:9428',
#         '-select.disable' => true,
#       },
#     },
#   }
#
# @param ensure
# @param service_name
# @param service_active
# @param service_enable
# @param user
# @param group
# @param binary_path
# @param options
#   Hash of named flag groups. Each group is a hash of CLI flag => value.
#   Groups are flattened and deduplicated before being passed to the binary.
#   Using named groups makes Hiera merging across layers predictable.
# @param limit_nofile
define victorialogs::instance (
  Enum['absent', 'present']                            $ensure         = 'present',
  String[1]                                            $service_name   = "victorialogs-${title}",
  Boolean                                              $service_active = true,
  Variant[Boolean, Enum['mask']]                       $service_enable = true,
  String[1]                                            $user           = $victorialogs::user,
  String[1]                                            $group          = $victorialogs::group,
  Stdlib::Absolutepath                                 $binary_path    = $victorialogs::install::binary_path,
  Hash[String[1], Victorialogs::Options]               $options        = {},
  Integer                                              $limit_nofile   = 2097152,
) {
  $real_service_active = $ensure ? {
    'absent' => false,
    default  => $service_active,
  }

  $real_service_enable = $ensure ? {
    'absent' => false,
    default  => $service_enable,
  }

  # Flatten named option groups into a single list of 'flag=value' strings.
  # Boolean true  => bare flag (e.g. '-select.disable')
  # Boolean false => flag omitted
  $args = $options.values().reduce([]) |$memo, $group| {
    $flags = $group.filter |$k, $v| { $v =~ Boolean ? { true => $v, default => true } }.map |$k, $v| {
      $v ? {
        true    => $k,
        default => "${k}=${v}",
      }
    }
    $memo + $flags
  }

  systemd::unit_file { "${service_name}.service":
    ensure  => $ensure,
    active  => $real_service_active,
    enable  => $real_service_enable,
    content => epp('victorialogs/instance.service.epp', {
      service_name => $service_name,
      user         => $user,
      group        => $group,
      binary_path  => $binary_path,
      args         => $args,
      limit_nofile => $limit_nofile,
    }),
  }

  # Restart the service when the binary symlink is replaced (archive installs only).
  # Package installs do not create a managed File resource for the binary;
  # install_method 'none' has no managed binary at all.
  if $victorialogs::install_method == 'archive' {
    File[$binary_path] ~> Systemd::Unit_file["${service_name}.service"]
  }
}
