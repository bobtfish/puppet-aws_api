require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_vpn).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods
  def self.instances
    []
  end
  def exists?
    @property_hash[:ensure] == :present
  end
  def create
  end
  def destroy
  end
end

