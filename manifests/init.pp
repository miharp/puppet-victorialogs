# @summary Installs and manages VictoriaLogs
#
# This is the only parameterised class in the module. All subordinate classes
# read from this scope; they accept no parameters of their own.
#
# @example Minimal — single-node with default options (version required for archive install)
#   class { 'victorialogs':
#     version => '1.49.0',
#   }
#
# @example Hiera — single-node, specific version
#   # site.pp
#   include victorialogs
#
#   # hiera data
#   victorialogs::version: '1.49.0'
#
# @example Cluster insert node
#   class { 'victorialogs':
#     version   => '1.49.0',
#     instances => {
#       insert => {
#         options => {
#           common => {
#             '-storageNode'    => 'vlstorage-01:9428,vlstorage-02:9428',
#             '-select.disable' => true,
#           },
#         },
#       },
#     },
#   }
#
# @param ensure
# @param edition
# @param install_method
# @param version
#   Release version (e.g. '1.49.0'). Required when install_method is 'archive'.
#   Omit to use the victorialogs::deploy Bolt plan which resolves 'latest' automatically.
# @param download_url
# @param checksum_url
# @param package_name
#   Package name used when install_method is 'package'.
# @param manage_user
# @param user
# @param shell
# @param manage_group
# @param group
# @param manage_homedir
# @param homedir
# @param homedir_mode
# @param homedir_owner
# @param homedir_group
# @param install_dir
# @param archive_binary
# @param package_binary
# @param tmp_dir
# @param enterprise_license_key
# @param enterprise_license_key_file
# @param instances
class victorialogs (
  Enum['absent', 'present']                               $ensure                    = 'present',
  Enum['oss', 'enterprise']                               $edition                   = 'oss',
  Enum['archive', 'package', 'none']                      $install_method            = 'archive',
  Optional[String[1]]                                     $version                   = undef,
  Boolean                                                 $manage_user               = true,
  String[1]                                               $user                      = 'victorialogs',
  String[1]                                               $shell                     = '/usr/sbin/nologin',
  Boolean                                                 $manage_group              = true,
  String[1]                                               $group                     = 'victorialogs',
  Boolean                                                 $manage_homedir            = true,
  Stdlib::Absolutepath                                    $homedir                   = '/var/lib/victorialogs',
  Stdlib::Filemode                                        $homedir_mode              = '0750',
  String[1]                                               $homedir_owner             = $user,
  String[1]                                               $homedir_group             = $group,
  Stdlib::Absolutepath                                    $install_dir               = "/opt/victorialogs-${version}-${edition}",
  String[1]                                               $package_name              = 'victorialogs',
  Stdlib::Absolutepath                                    $archive_binary            = '/usr/local/bin/victoria-logs-prod',
  Stdlib::Absolutepath                                    $package_binary            = '/usr/bin/victoria-logs-prod',
  Stdlib::Absolutepath                                    $tmp_dir                   = '/tmp',
  Optional[String[1]]                                     $enterprise_license_key    = undef,
  Optional[Stdlib::Absolutepath]                          $enterprise_license_key_file = undef,
  Optional[Stdlib::HTTPUrl]                               $download_url              = undef,
  Optional[Stdlib::HTTPUrl]                               $checksum_url              = undef,
  Hash[String[1], Victorialogs::InstanceType]             $instances                 = {
    single => {
      options => {
        common => {
          '-storageDataPath' => '/var/lib/victorialogs/victoria-logs-data',
        },
      },
    },
  },
) {
  contain victorialogs::user
  contain victorialogs::install

  Class['victorialogs::user'] -> Class['victorialogs::install']

  $instances.each |$instance_name, $instance_attrs| {
    victorialogs::instance { $instance_name:
      require => Class['victorialogs::install'],
      *       => $instance_attrs,
    }
  }
}
