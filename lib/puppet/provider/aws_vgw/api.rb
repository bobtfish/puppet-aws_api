require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_vgw).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
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
      ec2.regions[region_name].vpn_gateways.collect { |item| new_from_aws(item) }
    end.flatten
  end
  [:region].each do |ro_method|
    define_method("#{ro_method}=") do |v|
      fail "Cannot manage #{ro_method} is read-only once an vgw is created"
    end
  end
  def create
    begin
      vgw = ec2.regions[find_region_name_for_vpc_name resource[:vpc]].vpn_gateways.create([:vpn_type, :availability_zone].inject({}) { |acc, k| acc[k] = resource[k] if resource[k]; acc })
      tag_with_name vgw, resource[:name]
      if resource[:vpc]
        vgw.attach(find_vpc_item_by_name resource[:vpc])
      end
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
      rescue
      end
    end
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end
