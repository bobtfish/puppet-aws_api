require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_subnet).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.vpcs_for_region(region)
    ec2.regions[region].vpcs
  end
  def vpcs_for_region(region)
    self.class.vpcs_for_region region
  end
  def self.new_from_aws(vpc_id, item)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    new(
      :aws_item => item,
      :name     => name,
      :id       => item.id,
      :ensure   => :present,
      :vpc      => vpc_id,
      :cidr     => item.cidr_block,
      :az       => item.availability_zone_name,
      :tags     => tags.to_hash,
    )
  end
  def self.instances
    regions.collect do |region_name|
      vpcs_for_region(region_name).collect do |vpc|
        vpc_name = name_or_id vpc
        vpc.subnets.collect do |item|
          new_from_aws(vpc_name, item)
        end
      end.flatten
    end.flatten
  end
  [:vpc, :cidr].each do |ro_method|
    define_method("#{ro_method}=") do |v|
      fail "Cannot manage #{ro_method} is read-only once a subnet is created"
    end
  end
  def tags=(value)
    fail "Set tags not implemented yet"
  end
  def create
    begin
      vpc = find_vpc_item_by_name(resource[:vpc])
      subnet = vpc.subnets.create(resource[:cidr])
      wait_until_state subnet, :available
      tag_with_name subnet, resource[:name]
      tags = resource[:tags] || {}
      tags.each { |k,v| subnet.add_tag(k, :value => v) }
      subnet
    rescue Exception => e
      fail e
    end
  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

