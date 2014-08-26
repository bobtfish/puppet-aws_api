require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'aws_api.rb'))

Puppet::Type.type(:aws_igw).provide(:api, :parent => Puppet_X::Bobtfish::aws_api) do
  mk_resource_methods

  def self.new_from_aws(item)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    vpc_name = nil
    if item.vpc
      vpc_name = name_or_id item.vpc
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

  read_only(:vpc)

  def create
    if ! resource[:vpc]
      fail "Must have a vpc to create an igw"
    end
    region_name = find_region_name_for_vpc_name resource[:vpc]
    if !region_name
      fail "Cannot find VPC named #{resource[:vpc]} for igw"
    end
    igw = ec2.regions[region_name].internet_gateways.create()
    vpc = find_vpc_item_by_name(resource[:vpc])
    igw.attach(vpc)
    if resource[:route_to_main]
      vpc.route_tables.main_route_table.create_route( '0.0.0.0/0',
        :internet_gateway => igw
      )
    end

    tag_with_name igw, resource[:name]
    tags = resource[:tags] || {}
    tags.each { |k,v| igw.add_tag(k, :value => v) }
    igw
  end
  def destroy
    @property_hash[:aws_item].detach(@property_hash[:aws_item].vpc) if @property_hash[:aws_item].vpc
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

