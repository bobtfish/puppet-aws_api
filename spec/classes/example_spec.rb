require 'spec_helper'

describe 'aws_api' do
  context 'supported operating systems' do
    ['Debian', 'RedHat'].each do |osfamily|
      describe "aws_api class without any parameters on #{osfamily}" do
        let(:params) {{ }}
        let(:facts) {{
          :osfamily => osfamily,
        }}

        it { should compile.with_all_deps }

        it { should contain_class('aws_api::params') }
        it { should contain_class('aws_api::install').that_comes_before('aws_api::config') }
        it { should contain_class('aws_api::config') }
        it { should contain_class('aws_api::service').that_subscribes_to('aws_api::config') }

        it { should contain_service('aws_api') }
        it { should contain_package('aws_api').with_ensure('present') }
      end
    end
  end

  context 'unsupported operating system' do
    describe 'aws_api class without any parameters on Solaris/Nexenta' do
      let(:facts) {{
        :osfamily        => 'Solaris',
        :operatingsystem => 'Nexenta',
      }}

      it { expect { should contain_package('aws_api') }.to raise_error(Puppet::Error, /Nexenta not supported/) }
    end
  end
end
