require 'spec_helper'

describe 'victorialogs::github_download_url' do
  context 'with victorialogs archive' do
    it 'returns the correct archive URL' do
      is_expected.to run
        .with_params('1.49.0', 'oss', 'archive', 'x86_64')
        .and_return('https://github.com/VictoriaMetrics/VictoriaLogs/releases/download/v1.49.0/victoria-logs-linux-amd64-v1.49.0.tar.gz')
    end
  end

  context 'with victorialogs checksum' do
    it 'returns the checksum URL' do
      is_expected.to run
        .with_params('1.49.0', 'oss', 'checksum', 'x86_64')
        .and_return('https://github.com/VictoriaMetrics/VictoriaLogs/releases/download/v1.49.0/victoria-logs-linux-amd64-v1.49.0_checksums.txt')
    end
  end

  context 'with enterprise edition' do
    it 'includes -enterprise suffix' do
      result = subject.execute('1.49.0', 'enterprise', 'archive', 'x86_64')
      expect(result).to include('-enterprise')
    end
  end

  context 'with vlagent component' do
    it 'uses vlagent archive prefix' do
      result = subject.execute('1.49.0', 'oss', 'archive', 'x86_64', 'vlagent')
      expect(result).to include('vlagent-linux')
    end
  end

  context 'with aarch64 architecture' do
    it 'maps to arm64' do
      result = subject.execute('1.49.0', 'oss', 'archive', 'aarch64')
      expect(result).to include('arm64')
    end
  end

  context 'with unsupported architecture' do
    it 'raises an error' do
      is_expected.to run
        .with_params('1.49.0', 'oss', 'archive', 'mips64')
        .and_raise_error(Puppet::Error, /unsupported architecture/)
    end
  end
end
