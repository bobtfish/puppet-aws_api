require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_vpn).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.new_from_aws(region_name, item)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    new(
      :aws_item         => item,
      :name             => name,
      :id               => item.id,
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
      vpn = ec2.regions[resource[:region]].vpn_connections.create()
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

