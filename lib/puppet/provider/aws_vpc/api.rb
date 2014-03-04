require 'puppet/provider/ec2_api'

Puppet::Type.type(:aws_vpc).provide(:api, :parent => Puppet::Provider::Ec2_api) do
  mk_resource_methods
  def self.instances
    regions.collect do |region|
      ec2.regions[region].vpcs.collect do |item|
        new(
          :name             => item.id,
          :ensure           => :present,
          :cidr             => item.cidr_block,
          :dhcp_options_id  => item.dhcp_options_id,
          :instance_tenancy => item.instance_tenancy,
          :region           => region
        )
      end
    end.flatten
  end

  def exists?
    @property_hash[:ensure] == :present
  end
  def create
    raise("Cannot create yet")
  end
  def destroy
    raise("Cannot destroy yet")
  end
end

