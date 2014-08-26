require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'aws_api.rb'))

Puppet::Type.type(:aws_vpn).provide(:api, :parent => Puppet_X::Bobtfish::Aws_api) do
  mk_resource_methods

  def self.find_region(type)
    type_name, resource_name = if type[:vgw] and not type[:vgw].empty?
      [:aws_vgw, type[:vgw]]
    else
      [:aws_cgw, type[:cgw]]
    end
    provider = catalog_lookup(type.catalog, type_name, resource_name)
    provider.class.find_region(provider.resource)
  end

  def self.new_from_aws(region_name, item)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    cgw_name = nil
    if item.customer_gateway
      cgw_name = name_or_id item.customer_gateway
    end
    vgw_name = nil
    if item.vpn_gateway
      vgw_name = name_or_id item.vpn_gateway
    end
    new(
      :aws_item         => item,
      :name             => name,
      :id               => item.id,
      :cgw              => cgw_name,
      :vgw              => vgw_name,
      :region           => region_name,
      :ensure           => :present,
      :tags             => tags
    )
  end
  def self.instances
    regions.collect do |region_name|
      ec2.regions[region_name].vpn_connections.reject { |item| item.state == :deleting or item.state == :deleted }.collect { |item| new_from_aws(region_name,item) }
    end.flatten
  end
  read_only(:region, :vgw, :cgw, :type, :routing, :static_routes)
  def create
    begin
      cgw = regions.map do |region_name|
        ec2.regions[region_name].customer_gateways.find { |item| name_or_id(item)  == resource[:cgw] }
      end.reject { |i| i.nil? }[0]
      if !cgw
        fail("Cannot findcgw #{resource[:cgw]}")
      end
      vgw = regions.map do |region_name|
        ec2.regions[region_name].vpn_gateways.find { |item| name_or_id(item)  == resource[:vgw] }
      end.reject { |i| i.nil? }[0]
      if !vgw
        fail("Cannot find vgw #{resource[:vgw]}")
      end
      if !vgw.vpc
        fail("vgw #{resource[:vgw]} does not have a VPC associated with it, cannot find region")
      end
      region = find_region_name_for_vpc_name name_or_id(vgw.vpc)
      vpn = ec2.regions[region].vpn_connections.create({
        :customer_gateway => cgw,
        :vpn_gateway      => vgw,
      })
      tag_with_name vpn, resource[:name]
      tags = resource[:tags] || {}
      tags.each { |k,v| vpn.add_tag(k, :value => v) }
      vpn
    rescue Exception => e
      fail e
    end
  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

