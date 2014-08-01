require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_vpc).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.vpcs_for_region(region)
    ec2.regions[region].vpcs
  end
  def vpcs_for_region(region)
    self.class.vpcs_for_region region
  end
  def self.new_from_aws(region_name, item)
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
      :tags             => tags
    )
  end
  def self.instances
    regions.collect do |region_name|
      vpcs_for_region(region_name).collect { |item| new_from_aws(region_name, item) }
    end.flatten
  end
  [:cidr, :region, :instance_tenancy].each do |ro_method|
    define_method("#{ro_method}=") do |v|
      fail "Cannot manage #{ro_method} is read-only once a vpc is created"
    end
  end
  def dhcp_options=(value)
    dopts = find_dhopts_item_by_name(value)
    fail("Could not find dhcp options named '#{value}'") unless dopts
    @property_hash[:aws_item].dhcp_options = dopts.id
    @property_hash[:dhcp_options] = value
  end
  def create
    dhopts_name = nil
    if resource[:dhcp_options]
      dhopts = find_dhopts_item_by_name(resource[:dhcp_options])
      fail("Cannot find dhcp options named '#{resource[:dhcp_options]}'") unless dhopts
      dhopts_name = dhopts.id
    end

    vpc = ec2.regions[resource[:region]].vpcs.create(resource[:cidr])
    wait_until_state vpc, :available
    tag_with_name vpc, resource[:name]
    tags = resource[:tags] || {}
    tags.each { |k,v| vpc.add_tag(k, :value => v) }
    # Tag-name the default SG for this VPC so we know we're managing it:
    vpc.security_groups.find{|sg| sg.name == 'default'}.tags['Name'] = 'default'

    if dhopts_name
      vpc.dhcp_options = dhopts_name
    end
    vpc

  end
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

