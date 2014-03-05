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
      :region           => region_name,
      :ensure           => :present,
      :tags             => tags
    )
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

