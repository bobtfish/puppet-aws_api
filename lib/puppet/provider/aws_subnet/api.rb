require 'puppet/provider/ec2_api'

Puppet::Type.type(:aws_subnet).provide(:api, :parent => Puppet::Provider::Ec2_api) do
  mk_resource_methods
  def self.instances
    regions.collect do |region|
      ec2.regions[region].vpcs.collect do |vpc|
        vpc.subnets.collect do |item|
          tags = item.tags.to_h
          name = tags.delete('Name') || item.id
          new(
            :name             => name,
            :id               => item.id,
            :ensure           => :present,
            :vpc_id           => vpc.id,
            :cidr             => item.cidr_block,
            :az               => item.availability_zone_name,
            :tags             => tags
          )
        end
      end.flatten
    end.flatten
  end
  [:cidr].each do |ro_method|
    define_method("#{ro_method}=") do |v|
      fail "Cannot manage #{ro_method} is read-only once a vpc is created"
    end
  end
  def exists?
    @property_hash[:ensure] == :present
  end
  def create
  end
  def destroy
  end
end

