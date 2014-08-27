require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_routetable).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
  mk_resource_methods

  find_region_from :aws_subnet, :subnets

  primary_api :ec2, :collection => :route_tables

  def self.instance_from_aws_item(region, item)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    new(
      :aws_item         => item,
      :name             => name,
      :id               => item.id,
      :ensure           => :present,
      :tags             => tags,
      :main             => item.main? ? 'true' : 'false',
      :vpc              => name_or_id(item.vpc),
      :subnets          => item.subnets.map { |subnet| subnet.tags.to_h['Name'] || subnet.id },
      :routes           => item.routes.map { |route|
        {
          :destination_cidr_block => route.destination_cidr_block,
          :state => route.state,
          :target => name_or_id(route.target),
          :origin => route.origin,
          :network_interface => name_or_id(route.network_interface),
          :internet_gateway => name_or_id(route.internet_gateway)
        }.reject { |k, v| v.nil? } }
    )
  end

  read_only(:vpc, :subnets, :routes, :main)

  def create
    vpc = find_vpc_item_by_name resource[:vpc]
    if !vpc
      fail("Could not find vpc #{resource[:vpc]}")
    end
    my_region = find_region_name_for_vpc_name resource[:vpc]
    begin
      route_table = ec2.regions[my_region].route_tables.create({:vpc => vpc.id})
      tag_with_name route_table, resource[:name]
      tags = resource[:tags] || {}
      tags.each { |k,v| route.add_tag(k, :value => v) }
      route_table
    rescue Exception => e
      fail e
    end
  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

