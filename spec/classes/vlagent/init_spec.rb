require 'spec_helper'

describe 'victorialogs::vlagent' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with archive install and version set' do
        let(:params) do
          {
            install_method: 'archive',
            version:        '1.49.0',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('victorialogs::vlagent::user') }
        it { is_expected.to contain_class('victorialogs::vlagent::install') }
        it { is_expected.to contain_class('victorialogs::vlagent::service') }

        it { is_expected.to contain_group('vlagent').with_system(true) }
        it { is_expected.to contain_user('vlagent').with_system(true).with_shell('/usr/sbin/nologin') }

        it { is_expected.to contain_file('/opt/vlagent-1.49.0-oss').with_ensure('directory') }
        it { is_expected.to contain_archive('/tmp/vlagent-1.49.0-oss.tar.gz').with_extract_path('/opt/vlagent-1.49.0-oss') }
        it { is_expected.to contain_file('/opt/vlagent-1.49.0-oss/vlagent-prod').with_ensure('file') }
        it { is_expected.to contain_file('/usr/local/bin/vlagent-prod').with_ensure('link') }

        it { is_expected.to contain_systemd__unit_file('vlagent.service').with_active(true).with_enable(true) }
      end

      context 'with install_method => none' do
        let(:params) { { install_method: 'none' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_archive('/tmp/vlagent--oss.tar.gz') }
        it { is_expected.to contain_systemd__unit_file('vlagent.service') }
      end

      context 'with archive install and no version' do
        let(:params) { { install_method: 'archive' } }

        it { is_expected.to compile.and_raise_error(/version is required/) }
      end

      context 'with package install_method' do
        let(:params) { { install_method: 'package' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('vlagent').with_ensure('installed') }
      end

      context 'with ensure => absent' do
        let(:params) { { install_method: 'none', ensure: 'absent' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_group('vlagent').with_ensure('absent') }
        it { is_expected.to contain_user('vlagent').with_ensure('absent') }
        it { is_expected.to contain_systemd__unit_file('vlagent.service').with_active(false).with_enable(false) }
      end

      context 'with service_args' do
        let(:params) do
          {
            install_method: 'none',
            service_args: {
              '-remoteWrite.url' => 'http://localhost:9428/insert/jsonline',
              '-tls'             => true,
              '-debug'           => false,
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_systemd__unit_file('vlagent.service') }
      end

      context 'with enterprise license key' do
        let(:params) do
          {
            install_method: 'none',
            edition:        'enterprise',
            enterprise_license_key: 'my-license-key',
          }
        end

        it { is_expected.to compile.with_all_deps }
      end

      context 'class ordering' do
        let(:params) { { install_method: 'none' } }

        it { is_expected.to contain_class('victorialogs::vlagent::user').that_comes_before('Class[victorialogs::vlagent::install]') }
        it { is_expected.to contain_class('victorialogs::vlagent::install').that_notifies('Class[victorialogs::vlagent::service]') }
      end
    end
  end
end
