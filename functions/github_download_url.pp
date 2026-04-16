# @summary Build a GitHub release artifact URL for a VictoriaLogs component
#
# @param version
#   Release version string (e.g. '1.49.0'). Required; plans should resolve
#   'latest' before calling this function.
# @param edition
#   'oss' or 'enterprise'.
# @param download_type
#   'archive' returns a .tar.gz URL; 'checksum' returns the _checksums.txt URL.
# @param os_arch
#   Raw OS architecture string from $facts['os']['architecture'] (e.g. 'x86_64',
#   'aarch64'). Must be passed explicitly by the caller so the function stays
#   pure and works correctly in all compilation contexts (puppet agent, bolt apply).
# @param component
#   'victorialogs' or 'vlagent'.
#
# @return [String[1]] Full HTTPS download URL
function victorialogs::github_download_url(
  String[1]                              $version,
  Enum['oss', 'enterprise']              $edition,
  Enum['archive', 'checksum']            $download_type,
  String[1]                              $os_arch,
  Enum['victorialogs', 'vlagent']        $component = 'victorialogs',
) >> String[1] {
  # Map OS architecture fact to Go/release archive arch name
  $arch_map = {
    'x86_64'  => 'amd64',
    'amd64'   => 'amd64',
    'aarch64' => 'arm64',
    'arm64'   => 'arm64',
    'armv7l'  => 'arm',
    'i386'    => '386',
    'i686'    => '386',
  }

  unless $arch_map[$os_arch] {
    fail("victorialogs::github_download_url: unsupported architecture '${os_arch}'")
  }
  $go_arch = $arch_map[$os_arch]

  $edition_suffix = $edition ? {
    'enterprise' => '-enterprise',
    default      => '',
  }

  # The archive filename prefix differs from the binary name inside the archive.
  # e.g. victoria-logs-linux-arm64-v1.50.0.tar.gz contains 'victoria-logs-prod'
  $archive_prefix = $component ? {
    'vlagent' => 'vlagent',
    default   => 'victoria-logs',
  }

  $repo = 'VictoriaLogs'

  $tail = $download_type ? {
    'checksum' => '_checksums.txt',
    default    => '.tar.gz',
  }

  $base = "https://github.com/VictoriaMetrics/${repo}/releases/download/v${version}"
  $file = "${archive_prefix}-linux-${go_arch}-v${version}${edition_suffix}${tail}"

  "${base}/${file}"
}
