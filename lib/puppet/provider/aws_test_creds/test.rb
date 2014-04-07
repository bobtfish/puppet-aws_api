require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_test_creds).provide(:test, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.instances
    []
  end
  def create
    ec2.instances["not there"]
  end
end
