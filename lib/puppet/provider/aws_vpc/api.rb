require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_vpc).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods
  remove_method :tags= # We want the method inherited from the parent
  read_only :cidr, :id, :region, :instance_tenancy # can't set ID can we?

  def self.find_dopt(name_or_id)
    Puppet::Type.type(:aws_dopts).instances.find do |dopt|
      dopt.provider.name          == name_or_id ||
      dopt.provider.aws_item.id   == name_or_id
    end
  end
  def find_dopt(name_or_id); self.class.find_dopt(name_or_id); end

  def dhcp_options=(value)
    dopts = find_dopt(value)
    fail("Could not find dhcp options named '#{value}'") unless dopts
    @property_hash[:aws_item].dhcp_options = dopts.provider.aws_item
    @property_hash[:dhcp_options] = value
  end

  def self.new_from_aws(region_name, item, tags=nil)
    tags ||= item.tags.to_h
    name = tags.delete('Name') || item.id
    dopts_item = find_dopt(item.pre_dhcp_options_id)
    dopts_name = dopts_item.title if dopts_item

    new(
      :aws_item         => item,
      :name             => name,
      :id               => item.id,
      :ensure           => :present,
      :cidr             => item.cidr_block,
      :dhcp_options     => dopts_name,
      :instance_tenancy => item.instance_tenancy.to_s,
      :region           => region_name,
      :tags             => tags)
  end

  def self.instances_class; AWS::EC2::VPC; end

  def create
    fail("CIDR must be provided") unless resource[:cidr]

    vpc = ec2.regions[resource[:region]].vpcs.create(resource[:cidr])
    wait_until_state vpc, :available

    vpc.tags.set((resource[:tags] || {}).merge({'Name' => resource[:name]}))
    vpc.security_groups.first.tags['Name'] = resource[:name]

    if resource[:dhcp_options]
      dhopts = find_dopt(resource[:dhcp_options])
      fail("Cannot find dhcp options named '#{resource[:dhcp_options]}'") unless dhopts
      vpc.dhcp_options = dhopts
    end

    self.class.instance_variable_set('@instances', nil)

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
    if igw = vpc.internet_gateway
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

    AWS.reset_memoization
    @property_hash[:ensure] = :purged
  end

private

  def self.vpcs_for_region(region)
    ec2.regions[region].vpcs
  end

  def vpcs_for_region(region)
    self.class.vpcs_for_region region
  end
end
