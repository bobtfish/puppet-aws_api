require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_cgw).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
  mk_resource_methods

  find_region_from :region

  primary_api :ec2, :collection => :customer_gateways

  def self.instance_from_aws_item(region, item)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    new(
      :aws_item   => item,
      :name       => name,
      :id         => item.id,
      :bgp_asn    => item.bgp_asn,
      :type       => 'ipsec.1', # FIXME
      :region     => region,
      :ip_address => item.ip_address,
      :ensure     => :present, # TODO handle item.state :deleting and :deleted!!!
      :tags       => tags
    )
  end

  flushing_resource_methods :read_only => [
    :ip_address,
    :bgp_asn,
    :region,
    :type
  ]

  def create
    begin
      fail "Cannot create aws_cgw #{resource[:title]} without a region" unless resource[:region]
      region = ec2.regions[resource[:region]]
      fail "Cannot find region '#{resource[:region]} for resource #{resource[:title]}" unless region
      cgw = region.customer_gateways.create(resource[:bgp_asn].to_i, resource[:ip_address])
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

