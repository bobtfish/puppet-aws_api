require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_vpc).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
  include Puppetx::Bobtfish::TaggableProvider

  flushing_resource_methods :read_only => %w(cidr region instance_tenancy)

  find_region_from :region

  primary_api :ec2, :collection => :vpcs

  ensure_from_state(
    :available => :present,
    :pending => :available,
    &:state
  )

  def init_property_hash
    super
    map_init(
      :instance_tenancy,
      :cidr => :cidr_block,
    )
    init :dhcp_options, aws_item.dhcp_options.tags['Name']
  end

  def flush_when_ready
    flushing :ensure => :purged do
      self.purge_vpc
      return
    end
    flushing :ensure => :absent do
      aws_item.delete
      return
    end

    flushing :ensure => :present do
      also_flush :dhcp_options
      collection.create(resource[:cidr],
        :instance_tenancy => resource[:instance_tenancy]
      )
    end

    flushing :dhcp_options do |value|
      aws_item.dhcp_options = lookup(:aws_dopts, value).aws_item
    end

    super
  end


  def purge_vpc
    vpc = aws_item
    subnets = vpc.subnets

    # First, any load balancers living exclusively on our subnets
    elb.load_balancers.each do |lb|
      if lb.subnets.all?{|sn| subnets.include?(sn)}
        debug "Disposing of Elastic Load Balancer #{lb.name}"
        lb.delete
        wait_until { not lb.exists? }
      end
    end

    # Frozen copy of the current ec2 set
    instances = vpc.instances.to_a

    # Stop everything:
    instances.each do |node|
      debug "Stopping instance #{node.tags['Name']}"
      node.stop
    end
    instances.each do |node|
      wait_until { node.status == :stopped }

      # Dispose of EIPs
      eip = node.elastic_ip
      if eip
        debug "Releasing #{eip}"
        eip.disassociate
        wait_until { not eip.associated? }
        eip.release
      end
      # Force-release volumes, and destroy them
      node.attachments.to_a.each do |mnt, dev|
        debug "Detatching #{mnt}"
        volume = dev.volume
        dev.delete(:force => true)
        wait_until { volume.status == :available}
        debug "Disposing of #{volume.tags['Name']}"
        volume.delete
      end
      debug "Terminating #{node.tags['Name']}"
      node.terminate
      node.tags['Name'] = "#{node.tags['Name']}-terminated"
    end

    instances.each do |node|
      # Ensure everyone is terminated or else clearing SGs will fail
      wait_until {node.status == :terminated }
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
      igw_id = igw.tags['Name'] || igw.id
      debug "Detach Internet Gateway: #{igw_id}"
      igw.detach(vpc)
      debug "Disposing of #{igw_id}"
      igw.delete
    end

    # Murder RDS:
    dbis = []
    rds.db_instances.each do |dbi|
      if dbi.vpc_id == vpc.vpc_id
        debug "Deleting RDS instance: #{dbi.db_name}"
        dbis << dbi
        unless dbi.status == 'deleting'
          dbi.delete(:final_db_snapshot_identifier => "#{dbi.db_name}-final")
        end
      end
    end

    # wait_until do
    #   dbis.all? do |dbi|
    #     debug "Awaiting termination for RDS instance #{dbi.db_name}..."
    #     !dbi.exists? or dbi.db_instance_status == 'deleted'
    #   end
    # end

    rds.client.describe_db_subnet_groups()[:db_subnet_groups].each do |sng|
      if sng[:vpc_id] == vpc.vpc_id
        debug "Clearing subnets from RDS SNG #{sng[:db_subnet_group_name]}..."
        rds.client.delete_db_subnet_group(:db_subnet_group_name => sng[:db_subnet_group_name])
      end
    end

    # Subnets
    # Things get a bit wierd here with dependencies and waiting,
    # so just keep trying - it should work in a few seconds
    wait_until do
      begin
        subnets.each do |sn|
          debug "Disposing of subnet: #{sn.tags['Name']}"
          sn.delete
        end
      rescue Exception => e
        if e.message =~ /has dependencies and cannot be deleted/
          debug "Waiting for subnet to clear..."
        else
          raise
        end
      end
      subnets.all?{|sn| !(sn.state =~ /(pending|available)/)}
    end

    # Finally, the VPC itself
    debug "Purging VPC #{vpc.tags['Name']}"
    vpc.delete
  end
end

