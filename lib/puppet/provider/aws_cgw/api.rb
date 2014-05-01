require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_cgw).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.new_from_aws(region_name, item, account)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    new(
      :aws_item   => item,
      :name       => name,
      :id         => item.id,
      :bgp_asn    => item.bgp_asn,
      :type       => 'ipsec.1', # FIXME
      :region     => region_name,
      :ip_address => item.ip_address,
      :ensure     => :present,
      :tags       => tags,
      :account    => account
    )
  end
  def self.instances(creds=nil)
    instance_array = []
    regions.each do |region_name|
      creds.each do |cred|
        keys = cred.reject {|k,v| k == :name}
        instance_array << ec2(keys).regions[region_name].customer_gateways.collect { |item| new_from_aws(region_name,item,cred[:name]) }
      end
    end
    instance_array.flatten
  end
  [:ip_address, :bgp_asn, :region, :type].each do |ro_method|
    define_method("#{ro_method}=") do |v|
      fail "Cannot manage #{ro_method} is read-only once an cgw is created"
    end
  end
  def create
    begin
      cgw = ec2.regions[resource[:region]].customer_gateways.create(resource[:bgp_asn].to_i, resource[:ip_address])
      tag_with_name cgw, resource[:name]
      tags = resource[:tags] || {}
      tags.each { |k,v| cgw.add_tag(k, :value => v) }
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

