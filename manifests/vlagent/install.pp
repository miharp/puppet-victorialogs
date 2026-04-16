# @summary Installs the vlagent binary
# @api private
class victorialogs::vlagent::install {
  assert_private()

  case $victorialogs::vlagent::install_method {
    'archive': {
      unless $victorialogs::vlagent::version {
        fail('victorialogs::vlagent: $version is required when install_method is archive')
      }

      $install_dir      = $victorialogs::vlagent::install_dir
      $extracted_binary = "${install_dir}/vlagent-prod"
      $archive_path     = "${victorialogs::vlagent::tmp_dir}/vlagent-${victorialogs::vlagent::version}-${victorialogs::vlagent::edition}.tar.gz"

      $arch = $facts['os']['architecture']
      $real_download_url = $victorialogs::vlagent::download_url ? {
        undef   => victorialogs::github_download_url($victorialogs::vlagent::version, $victorialogs::vlagent::edition, 'archive', $arch, 'vlagent'),
        default => $victorialogs::vlagent::download_url,
      }
      $real_checksum_url = $victorialogs::vlagent::checksum_url ? {
        undef   => victorialogs::github_download_url($victorialogs::vlagent::version, $victorialogs::vlagent::edition, 'checksum', $arch, 'vlagent'),
        default => $victorialogs::vlagent::checksum_url,
      }

      file { $install_dir:
        ensure => stdlib::ensure($victorialogs::vlagent::ensure, 'directory'),
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }

      archive { $archive_path:
        ensure       => $victorialogs::vlagent::ensure,
        source       => $real_download_url,
        checksum_url => $real_checksum_url,
        extract      => true,
        extract_path => $install_dir,
        creates      => $extracted_binary,
        cleanup      => true,
        require      => File[$install_dir],
        before       => File[$extracted_binary],
      }

      file { $extracted_binary:
        ensure => stdlib::ensure($victorialogs::vlagent::ensure, 'file'),
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }

      file { $victorialogs::vlagent::archive_binary:
        ensure => stdlib::ensure($victorialogs::vlagent::ensure, 'link'),
        target => $extracted_binary,
      }

      $binary_path = $victorialogs::vlagent::archive_binary
    }

    'package': {
      $package_ensure = $victorialogs::vlagent::ensure ? {
        'absent' => 'absent',
        default  => $victorialogs::vlagent::version.then |$v| { $v }.lest || { 'installed' },
      }

      package { $victorialogs::vlagent::package_name:
        ensure => $package_ensure,
      }

      $binary_path = $victorialogs::vlagent::package_binary
    }

    default: {
      $binary_path = $victorialogs::vlagent::archive_binary
    }
  }
}
