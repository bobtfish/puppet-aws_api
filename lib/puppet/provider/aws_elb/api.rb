require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_elb).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do

  flushing_resource_methods :read_only => [
    :listeners, :subnets, :security_groups, :scheme]

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
    init :listeners, aws_item.listeners.map{ |l| {
      'port' => l.port.to_s,
      'protocol' => l.protocol.to_s,
      'instance_port' => l.instance_port.to_s,
      'instance_protocol' => l.instance_protocol.to_s
    }}
    init :subnets, aws_item.subnets.map {|s| s.tags['Name']}
    init :security_groups, aws_item.security_groups.collect(&:name)
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

    flushing :ensure => :create do
      elb.collection.create(resource[:name],
        :listeners => resource[:listeners].map{ |l| {
          :load_balancer_port => l['port'].to_i,
          :protocol => l['protocol'],
          :instance_port => l['instance_port'].to_i,
          :instance_protocol => l['instance_protocol']
        }},
        :subnets => resource[:subnets].map{|s| lookup(:aws_subnet, s).aws_item },
        :security_groups => resource[:security_groups].map{ |s|
          lookup(:aws_security_group, s).aws_item
        },
        :scheme => resource[:scheme].to_s
      )
    end

    flushing :health_check, :target do |health, target|
      aws_item.configure_health_check(
        :healthy_threshold => health['healthy_threshold'].to_i,
        :unhealthy_threshold => health['unhealthy_threshold'].to_i,
        :interval => health['interval'].to_i,
        :timeout => health['timeout'].to_i,
        :target => target
      )
    end

    flushing :instances do |instances|
      wanted = instances.map{|name| lookup(:aws_ec2_instance, name)}
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


  end

  def substitutions
    {
      :cname => aws_item.dns_name,
    }
  end
end

