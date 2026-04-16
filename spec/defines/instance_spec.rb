require 'spec_helper'

describe 'victorialogs::instance' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }
      let(:pre_condition) do
        "class { 'victorialogs': install_method => 'none' }"
      end
      let(:title) { 'primary' }

      context 'with defaults' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_systemd__unit_file('victorialogs-primary.service') }
      end

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent' } }

        it { is_expected.to compile.with_all_deps }
        it do
          is_expected.to contain_systemd__unit_file('victorialogs-primary.service')
            .with_active(false)
            .with_enable(false)
        end
      end

      context 'with custom options' do
        let(:params) do
          {
            options: {
              'common' => { '-storageDataPath' => '/data/vl' },
              'syslog' => { '-syslog.listenAddr.tcp' => ':514' },
            },
          }
        end

        it { is_expected.to compile.with_all_deps }
      end

      context 'with custom service_name' do
        let(:params) { { service_name: 'vl-custom' } }

        it { is_expected.to contain_systemd__unit_file('vl-custom.service') }
      end
    end
  end
end
