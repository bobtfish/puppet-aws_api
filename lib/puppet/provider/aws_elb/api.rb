require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_elb).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do

  flushing_resource_methods :read_only => [
    :subnets, :security_groups, :scheme]

  find_region_from :aws_subnet, :subnets

  primary_api :elb, :collection => :load_balancers

  ensure_from_state(
    true => :present,
    false => :absent,
    &:exists?
  )

  def init_property_hash
    super
    map_init(:name, :scheme)
    init :listeners, aws_item.listeners.map(&method(:unmunge_listeners))
    init :subnets, aws_item.subnets.map {|s| s.tags['Name']}
    init :security_groups, aws_item.security_groups.collect{ |sg|
      "#{sg.vpc.tags['Name'] || sg.vpc_id}:#{sg.name}"
    }
    init :health_check, {
      'healthy_threshold' => aws_item.health_check[:healthy_threshold].to_s,
      'unhealthy_threshold' => aws_item.health_check[:unhealthy_threshold].to_s,
      'interval' => aws_item.health_check[:interval].to_s,
      'timeout' => aws_item.health_check[:timeout].to_s,
    }
    init :target, aws_item.health_check[:target]
    init :instances, aws_item.instances.map {|i| i.tags['Name']}
  end

  def flush_when_ready
    flushing :ensure => :absent do
      aws_item.delete
      return
    end

    flushing :ensure => :present do
      also_flush(:health_check, :instances)

      collection.create(resource[:name],
        :listeners => resource[:listeners].map(&method(:munge_listeners)),
        :subnets => resource[:subnets].map{|s| lookup(:aws_subnet, s).aws_item },
        :security_groups => resource[:security_groups].map{ |s|
          lookup(:aws_security_group, s).aws_item
        },
        :scheme => resource[:scheme].to_s
      )
    end


    flushing :health_check, :target do |health, target|
      # Always merge with current values:
      health = (health || {}).merge(@property_hash[:health_check] || {})
      # same idea with target (in case only one flushes)
      target ||= @property_hash[:target]
      aws_item.configure_health_check(
        :healthy_threshold => health['healthy_threshold'].to_i,
        :unhealthy_threshold => health['unhealthy_threshold'].to_i,
        :interval => health['interval'].to_i,
        :timeout => health['timeout'].to_i,
        :target => target
      )
    end

    flushing :instances do |instances|
      wanted = instances.map{|name| lookup(:aws_ec2_instance, name).aws_item}
      current = aws_item.instances.to_a
      unwanted = current - wanted
      needed = wanted - current
      if unwanted.any?
        aws_item.instances.deregister(*unwanted)
      end
      if needed.any?
        aws_item.instances.register(*needed)
      end
    end

    flushing :listeners do |listeners|
      # First, index current and wanted by port
      wanted = Hash[listeners.collect{|l| [l['port'].to_i, l]}]
      current = Hash[aws_item.listeners.collect{|l| [l.port, l]}]

      # Now collect just the ports so we can do some set math
      wanted_ports = wanted.keys
      current_ports = current.keys

      unwanted_ports = current_ports - wanted_ports
      unwanted_ports.each do |port|
        current[port].delete
      end

      changing_ports = current_ports & wanted_ports
      changing_ports.each do |port|
        current[port].delete
        aws_item.listeners.create(munge_listeners(wanted[port]))
      end

      new_ports = wanted_ports - current_ports
      new_ports.each do |port|
        aws_item.listeners.create(munge_listeners(wanted[port]))
      end
    end

    super
  end

  def substitutions
    {
      :cname => aws_item.canonical_hosted_zone_name,
      :port => aws_item.listeners.first.port,
    }
  end

  protected
  def munge_listeners(listener)
    {
      :load_balancer_port => listener['port'].to_i,
      :protocol => listener['protocol'],
      :instance_port => listener['instance_port'].to_i,
      :instance_protocol => listener['instance_protocol']
    }
  end

  def unmunge_listeners(listener)
    {
      'port' => listener.port,
      'protocol' => listener.protocol.to_s,
      'instance_port' => listener.instance_port,
      'instance_protocol' => listener.instance_protocol.to_s
    }
  end
end

