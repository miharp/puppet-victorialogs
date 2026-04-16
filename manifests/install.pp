# @summary Installs the VictoriaLogs binary
# @api private
class victorialogs::install {
  assert_private()

  case $victorialogs::install_method {
    'archive': {
      unless $victorialogs::version {
        fail('victorialogs: $version is required when install_method is archive')
      }

      $install_dir      = $victorialogs::install_dir
      $extracted_binary = "${install_dir}/victoria-logs-prod"
      $archive_path     = "${victorialogs::tmp_dir}/victoria-logs-${victorialogs::version}-${victorialogs::edition}.tar.gz"

      $arch = $facts['os']['architecture']
      $real_download_url = $victorialogs::download_url ? {
        undef   => victorialogs::github_download_url($victorialogs::version, $victorialogs::edition, 'archive', $arch),
        default => $victorialogs::download_url,
      }
      $real_checksum_url = $victorialogs::checksum_url ? {
        undef   => victorialogs::github_download_url($victorialogs::version, $victorialogs::edition, 'checksum', $arch),
        default => $victorialogs::checksum_url,
      }

      file { $install_dir:
        ensure => stdlib::ensure($victorialogs::ensure, 'directory'),
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }

      archive { $archive_path:
        ensure       => $victorialogs::ensure,
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
        ensure => stdlib::ensure($victorialogs::ensure, 'file'),
        owner  => 'root',
        group  => 'root',
        mode   => '0755',
      }

      file { $victorialogs::archive_binary:
        ensure => stdlib::ensure($victorialogs::ensure, 'link'),
        target => $extracted_binary,
      }

      # Expose the binary path for use by instances
      $binary_path = $victorialogs::archive_binary
    }

    'package': {
      $package_ensure = $victorialogs::ensure ? {
        'absent' => 'absent',
        default  => $victorialogs::version.then |$v| { $v }.lest || { 'installed' },
      }

      package { $victorialogs::package_name:
        ensure => $package_ensure,
      }

      $binary_path = $victorialogs::package_binary
    }

    default: {
      # install_method => 'none': binary management is handled externally
      $binary_path = $victorialogs::archive_binary
    }
  }
}
