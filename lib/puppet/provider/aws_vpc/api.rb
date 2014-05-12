require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_vpc).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.vpcs_for_region(region, keys)
    ec2(keys).regions[region].vpcs
  end
  def vpcs_for_region(region)
    self.class.vpcs_for_region region
  end
  def self.new_from_aws(region_name, item, account)
    tags = item.tags.to_h
    name = tags.delete('Name') || item.id
    dopts_item = find_dhopts_item_by_name item.dhcp_options_id
    dopts_name = nil
    if dopts_item
      dopts_name = name_or_id dopts_item
    end
    new(
      :aws_item         => item,
      :name             => name,
      :id               => item.id,
      :ensure           => :present,
      :cidr             => item.cidr_block,
      :dhcp_options     => dopts_name,
      :instance_tenancy => item.instance_tenancy.to_s,
      :region           => region_name,
      :tags             => tags,
      :account          => account
    )
  end
  def self.instances(creds=nil)
    region_list = nil
    creds.collect do |cred|
      keys = cred.reject {|k,v| k == :name}
      region_list ||= regions(keys)
      region_list.collect do |region_name|
        vpcs_for_region(region_name, keys).collect { |item| new_from_aws(region_name, item, cred[:name]) }
      end.flatten
    end.flatten
  end
  [:cidr, :region, :instance_tenancy].each do |ro_method|
    define_method("#{ro_method}=") do |v|
      fail "Cannot manage #{ro_method} is read-only once a vpc is created"
    end
  end
  def dhcp_options=(value)
    @property_hash[:aws_item].dhcp_options = find_dhopts_item_by_name(value).id
  end
  def create
    begin
      dhopts_name = nil
      if resource[:dhcp_options]
        dhopts_name = find_dhopts_item_by_name(resource[:dhcp_options]).id
      end
      vpc = ec2.regions[resource[:region]].vpcs.create(resource[:cidr])
      wait_until_state vpc, :available
      tag_with_name vpc, resource[:name]
      tags = resource[:tags] || {}
      tags.each { |k,v| vpc.add_tag(k, :value => v) }
      if dhopts_name
        vpc.dhcp_options = dhopts_name
      end
      vpc
    rescue Exception => e
      fail e
    end
  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

