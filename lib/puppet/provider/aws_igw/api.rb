require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_igw).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.new_from_aws(item)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    vpc_name = nil
    if item.vpc
      vpc_tags = item.vpc.tags
      vpc_name = vpc_tags.has_key?('Name') ? vpc_tags['Name'] : item.vpc.id
    end
    new(
      :aws_item         => item,
      :name             => name,
      :id               => item.id,
      :vpc              => vpc_name,
      :ensure           => :present,
      :tags             => tags
    )
  end
  def self.instances
    regions.collect do |region_name|
      ec2.regions[region_name].internet_gateways.collect { |item| new_from_aws(item) }
    end.flatten
  end
  def create
    begin
      if ! resource[:vpc]
        fail "Must have a vpc to create an igw"
      end
      region_name = find_region_name_for_vpc_name resource[:vpc]
      if !region_name
        fail "Cannot find VPC named #{resource[:vpc]} for igw"
      end
      igw = ec2.regions[region_name].internet_gateways.create()
      if resource[:vpc]
        igw.attach(find_vpc_item_by_name resource[:vpc])
      end
      tag_with_name igw, resource[:name]
      tags = resource[:tags] || {}
      tags.each { |k,v| igw.add_tag(k, :value => v) }
      igw
    rescue Exception => e
      fail e
    end
  end
  def destroy
    @property_hash[:aws_item].detach(@property_hash[:aws_item].vpc) if @property_hash[:aws_item].vpc
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

