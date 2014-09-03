require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_vgw).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
  include Puppetx::Bobtfish::TaggableProvider

  flushing_resource_methods :read_only => [:vpc, :vpn_type]

  find_region_from :aws_vpc, :vpc

  primary_api :ec2, :collection => :vpn_gateways


  def init_property_hash
    super
    init :vpc, aws_item.vpc.tags['Name'] || aws_item.vpc_id
    vpnc = aws_item.vpn_connections.first
    init :vpn_type, vpnc.vpn_type
  end


  # TODO: impelment using flush_when_ready

  def vpc=(name)
    @property_hash[:aws_item].attach(find_vpc_item_by_name(name))
  end
  def create
    if !resource[:vpc]
      fail("Must have a vpc")
    end
    begin
      if resource[:availability_zone]
        my_region = find_region_name_for_vpc_name resource[:vpc]
        if !my_region
          fail("Cannot find VPC #{resource[:vpc]}")
        end
        azs = ec2.regions[my_region].availability_zones
        if !azs.find { |az| az.to_s == resource[:availability_zone] }
          fail("Cannot find az '#{resource[:availability_zone]}', need to choose.com: #{azs.to_a.join(", ")}")
        end
      end
      vgw = ec2.regions[find_region_name_for_vpc_name(resource[:vpc])].vpn_gateways.create([:vpn_type, :availability_zone].inject({}) { |acc, k| acc[k] = resource[k] if resource[k]; acc })
      tag_with_name vgw, resource[:name]
      vgw.attach(find_vpc_item_by_name(resource[:vpc]))
      tags = resource[:tags] || {}
      tags.each { |k,v| vgw.add_tag(k, :value => v) }
      vgw
    rescue Exception => e
      fail e
    end
  end
  def destroy
    if @property_hash[:aws_item].vpc
      begin # This blows up if already detached, but I can't find how to work that out. FIXME
        @property_hash[:aws_item].detach(@property_hash[:aws_item].vpc)
        sleep 240 # Double FIXME - We should be able to wait for detached
      rescue
      end
    end
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

