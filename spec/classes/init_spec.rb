require 'spec_helper'

describe 'victorialogs' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'with default params (install_method => none, no version required)' do
        let(:params) { { install_method: 'none' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('victorialogs::user') }
        it { is_expected.to contain_class('victorialogs::install') }
        it { is_expected.to contain_victorialogs__instance('single') }

        it { is_expected.to contain_group('victorialogs').with_system(true) }
        it { is_expected.to contain_user('victorialogs').with_system(true).with_shell('/usr/sbin/nologin') }
        it { is_expected.to contain_file('/var/lib/victorialogs').with_ensure('directory').with_mode('0750') }
        it { is_expected.to contain_systemd__unit_file('victorialogs-single.service') }
      end

      context 'with archive install_method and version set' do
        let(:params) do
          {
            install_method: 'archive',
            version:        '1.49.0',
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_class('victorialogs::user') }
        it { is_expected.to contain_class('victorialogs::install') }

        it { is_expected.to contain_file('/opt/victorialogs-1.49.0-oss').with_ensure('directory') }
        it { is_expected.to contain_archive('/tmp/victoria-logs-1.49.0-oss.tar.gz').with_extract_path('/opt/victorialogs-1.49.0-oss') }
        it { is_expected.to contain_file('/opt/victorialogs-1.49.0-oss/victoria-logs-prod').with_ensure('file') }
        it { is_expected.to contain_file('/usr/local/bin/victoria-logs-prod').with_ensure('link') }
      end

      context 'with archive install_method and no version' do
        let(:params) { { install_method: 'archive' } }

        it { is_expected.to compile.and_raise_error(/version is required/) }
      end

      context 'with package install_method' do
        let(:params) { { install_method: 'package' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_package('victorialogs').with_ensure('installed') }
      end

      context 'with ensure => absent' do
        let(:params) { { install_method: 'none', ensure: 'absent' } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_group('victorialogs').with_ensure('absent') }
        it { is_expected.to contain_user('victorialogs').with_ensure('absent') }
      end

      context 'with manage_user => false' do
        let(:params) { { install_method: 'none', manage_user: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_user('victorialogs') }
      end

      context 'with manage_group => false' do
        let(:params) { { install_method: 'none', manage_group: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_group('victorialogs') }
      end

      context 'with manage_homedir => false' do
        let(:params) { { install_method: 'none', manage_homedir: false } }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_file('/var/lib/victorialogs') }
      end

      context 'with multiple instances' do
        let(:params) do
          {
            install_method: 'none',
            instances: {
              'insert' => {
                'options' => { 'common' => { '-select.disable' => true } },
              },
              'select' => {
                'options' => { 'common' => { '-insert.disable' => true } },
              },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_victorialogs__instance('insert') }
        it { is_expected.to contain_victorialogs__instance('select') }
        it { is_expected.to contain_systemd__unit_file('victorialogs-insert.service') }
        it { is_expected.to contain_systemd__unit_file('victorialogs-select.service') }
      end

      context 'class ordering' do
        let(:params) { { install_method: 'none' } }

        it { is_expected.to contain_class('victorialogs::user').that_comes_before('Class[victorialogs::install]') }
        it { is_expected.to contain_victorialogs__instance('single').that_requires('Class[victorialogs::install]') }
      end
    end
  end
end
