# @summary Installs and manages vlagent (VictoriaLogs log collector/forwarder)
#
# @example Minimal — forward logs to a local VictoriaLogs instance
#   class { 'victorialogs::vlagent':
#     version      => '1.49.0',
#     service_args => {
#       '-remoteWrite.url' => 'http://localhost:9428/insert/jsonline',
#     },
#   }
#
# @example Hiera
#   # site.pp
#   include victorialogs::vlagent
#
#   # hiera data
#   victorialogs::vlagent::version: '1.49.0'
#   victorialogs::vlagent::service_args:
#     '-remoteWrite.url': 'http://vlinsert-01:9428/insert/jsonline'
#
# @param ensure
# @param edition
# @param install_method
# @param version
# @param download_url
# @param checksum_url
# @param package_name
# @param manage_user
# @param user
# @param shell
# @param manage_group
# @param group
# @param install_dir
# @param archive_binary
# @param package_binary
# @param tmp_dir
# @param service_args
#   Flat hash of CLI flag => value pairs passed directly to the vlagent binary.
# @param service_active
# @param service_enable
# @param service_name
# @param limit_nofile
# @param enterprise_license_key
# @param enterprise_license_key_file
class victorialogs::vlagent (
  Enum['absent', 'present']                                $ensure                      = 'present',
  Enum['oss', 'enterprise']                                $edition                     = 'oss',
  Enum['archive', 'package', 'none']                       $install_method              = 'archive',
  Optional[String[1]]                                      $version                     = undef,
  Boolean                                                  $manage_user                 = true,
  String[1]                                                $user                        = 'vlagent',
  String[1]                                                $shell                       = '/usr/sbin/nologin',
  Boolean                                                  $manage_group                = true,
  String[1]                                                $group                       = 'vlagent',
  Stdlib::Absolutepath                                     $install_dir                 = "/opt/vlagent-${version}-${edition}",
  Stdlib::Absolutepath                                     $archive_binary              = '/usr/local/bin/vlagent-prod',
  Stdlib::Absolutepath                                     $package_binary              = '/usr/bin/vlagent-prod',
  Stdlib::Absolutepath                                     $tmp_dir                     = '/tmp',
  String[1]                                                $package_name                = 'vlagent',
  Hash[String[1], Variant[String, Integer, Boolean]]       $service_args                = {},
  Boolean                                                  $service_active              = true,
  Variant[Boolean, Enum['mask']]                           $service_enable              = true,
  String[1]                                                $service_name                = 'vlagent',
  Integer                                                  $limit_nofile                = 2097152,
  Optional[String[1]]                                      $enterprise_license_key      = undef,
  Optional[Stdlib::Absolutepath]                           $enterprise_license_key_file = undef,
  Optional[Stdlib::HTTPUrl]                                $download_url                = undef,
  Optional[Stdlib::HTTPUrl]                               $checksum_url                = undef,
) {
  contain victorialogs::vlagent::user
  contain victorialogs::vlagent::install
  contain victorialogs::vlagent::service

  Class['victorialogs::vlagent::user']
  -> Class['victorialogs::vlagent::install']
  ~> Class['victorialogs::vlagent::service']
}
