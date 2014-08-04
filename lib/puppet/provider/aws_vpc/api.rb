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
  read_only(:cidr, :id,  :region, :aws_dops, :instance_tenancy) # can't set ID can we?
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
  def purge
    vpc = @property_hash[:aws_item]
    subnets = vpc.subnets

    # First, any load balancers:
    regions = subnets.collect do |sn|
      sn.availability_zone.region_name
    end
    regions.each do |region|
      elb(region).load_balancers.each do |lb|
        if lb.subnets.all?{|sn| subnets.include?(sn)}
          debug "Disposing of Elastic Load Balancer #{lb.name}"
          lb.delete
          sleep 1 until not lb.exists?
        end
      end
    end
    # Freeze the current set
    instances = vpc.instances.to_a

    # Stop everything:
    instances.each do |node|
      debug "Stopping instance #{node.tags['Name']}"
      node.stop
    end
    instances.each do |node|
      wait_until_status(node, :stopped)
      # Dispose of EIPs
      eip = node.elastic_ip
      if eip
        debug "Releasing #{eip}"
        eip.disassociate
        eip.release
      end
      # Force-release volumes, and destroy them
      node.attachments.to_a.each do |mnt, dev|
        debug "Detatching #{mnt}"
        volume = dev.volume
        dev.delete(:force => true)
        wait_until_status(volume, :available)
        debug "Disposing of #{dev.volume.tags['Name']}"
        volume.delete
      end
      debug "Terminating #{node.tags['Name']}"
      node.terminate
      node.tags['Name'] = "#{node.tags['Name']}-terminated"
    end

    instances.each do |node|
      # Ensure everyone is terminated or else clearing SGs will fail
      wait_until_status(node, :terminated)
    end

    # Security groups
    vpc.security_groups.each do |sg|
      next if sg.name == 'default'
      debug "Disposing of Security Group: #{sg.name}"
      sg.delete
    end

    # Gateways
    igw = vpc.internet_gateway
    if igw
      debug "Detach Internet Gateway: #{igw.tags['Name']}"
      igw.detach(vpc)
      debug "Disposing of #{igw.tags['Name']}"
      igw.delete
    end

    # Just give everything a little bit of time to settle so we don't get depdendency
    # violations - experience has shown this to be simpler and more reliable than
    # explicit checks.
    sleep 2

    # Subnets
    subnets.each do |sn|
      debug "Disposing of subnet: #{sn.tags['Name']}"
      sn.delete
    end

    # Finally, the VPC itself
    debug "Purging VPC #{vpc.tags['Name']}"
    vpc.delete
    @property_hash[:ensure] = :purged
  end
end

