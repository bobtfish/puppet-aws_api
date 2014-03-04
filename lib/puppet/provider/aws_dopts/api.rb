require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_dopts).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
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
      ec2.regions[region_name].dhcp_options.collect { |item| new_from_aws(region_name,item) }
    end.flatten
  end
  def exists?
    @property_hash[:ensure] == :present
  end
  def create
    begin
      dopts = ec2.regions[resource[:region]].dhcp_options.create()
      tag_with_name dopts, resource[:name]
      tags = resource[:tags] || {}
      tags.each { |k,v| dopts.add_tag(k, :value => v) }
      dopts
    rescue Exception => e
      fail e
    end
  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

