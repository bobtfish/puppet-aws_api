require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_vpn).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.new_from_aws(region_name, item)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    cgw_name = nil
    if item.customer_gateway
      customer_gateway_tags = item.customer_gateway.tags
      cgw_name = customer_gateway_tags.has_key?('Name') ? customer_gateway_tags['Name'] : item.customer_gateway.id
    end
    vgw_name = nil
    if item.vpn_gateway
      vpn_gateway_tags = item.vpn_gateway.tags
      vgw_name = vpn_gateway_tags.has_key?('Name') ? vpn_gateway_tags['Name'] : item.vpn_gateway.id
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
      ec2.regions[region_name].vpn_connections.collect { |item| new_from_aws(region_name,item) }
    end.flatten
  end
  [:region].each do |ro_method|
    define_method("#{ro_method}=") do |v|
      fail "Cannot manage #{ro_method} is read-only once an vpn is created"
    end
  end
  def create
    begin
      cgw = regions.map do |region_name|
        ec2.regions[region_name].customer_gateways.find { |item| (item.tags.to_h['Name'] || item.id)  == resource[:cgw] }
      end.reject { |i| i.nil? }[0]
      if !cgw
        fail("Cannot findcgw #{resource[:cgw]}")
      end
      vgw = regions.map do |region_name|
        ec2.regions[region_name].vpn_gateways.find { |item| (item.tags.to_h['Name'] || item.id)  == resource[:vgw] }
      end.reject { |i| i.nil? }[0]
      if !vgw
        fail("Cannot find vgw #{resource[:vgw]}")
      end
      if !vgw.vpc
        fail("vgw #{resource[:vgw]} does not have a VPC associated with it, cannot find region")
      end
      region = find_region_name_for_vpc_name (vgw.vpc.tags.to_h['Name'] || vgw.vpc.id)
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

