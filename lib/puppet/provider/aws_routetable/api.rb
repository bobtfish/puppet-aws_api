require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_routetable).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.new_from_aws(region_name, item)
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
  [:vpc, :subnets, :routes].each do |ro_method|
    define_method("#{ro_method}=") do |v|
      fail "Cannot manage #{ro_method} is read-only in this version of the module.."
    end
  end
  def self.instances
    regions.collect do |region_name|
      ec2.regions[region_name].route_tables.collect { |item| new_from_aws(region_name,item) }
    end.flatten
  end
  def exists?
    @property_hash[:ensure] == :present
  end
  def create
    begin
      cgw = ec2.regions[resource[:region]].route_tables.create()
      tag_with_name cgw, resource[:name]
      tags = resource[:tags] || {}
      tags.each { |k,v| igw.add_tag(k, :value => v) }
      cgw
    rescue Exception => e
      fail e
    end
  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

