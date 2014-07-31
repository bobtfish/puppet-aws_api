require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))


Puppet::Type.type(:aws_elb).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods


  def self.new_from_aws(region_name, item)
    health_check = item.health_check
    target = health_check.delete(:target)

    new(
      :aws_item         => item,
      :name             => item.name,
      :listeners         => item.listeners.map { |l| {
        :port => l.port,
        :protocol => l.protocol,
        :instance_port => l.instance_port,
        :instance_protocol => l.instance_protocol
      }},
      :subnets          => item.subnets.map {|s| s.tags['Name']},
      :security_groups  => item.security_groups.collect(&:name),
      :scheme           => item.scheme,
      :health_check     => health_check,
      :target           => target,
      :instances        => item.instances.map {|i| s.tags['Name']}
    )
  end
  def self.instances
    regions.collect{ |region| 
      elb(region).load_balancers.collect { |item| new_from_aws(item) }}.flatten
  end
  

  def create
    listeners = resource[:listeners].map do |l|
      {
        :load_balancer_port => l['port'].to_i,
        :protocol => l['protocol'],
        :instance_port => l['instance_port'].to_i,
        :instance_protocol => l['instance_protocol']
      }
    end

    subnets = resource[:subnets].map{|s| lookup(:aws_subnet, s) }
    region = subnets.first.availability_zone.region_name
    lb = elb(region).load_balancers.create(
      resource[:name],
      :listeners => listeners,
      :subnets => subnets,
      :security_groups => resource[:security_groups].map{|s| lookup(:aws_security_group, s)},
      :scheme => resource[:scheme].to_s
    )
    
    lb.configure_health_check(
        :healthy_threshold => resource['health_check']['healthy_threshold'].to_i,
        :unhealthy_threshold => resource['health_check']['unhealthy_threshold'].to_i,
        :interval => resource['health_check']['interval'].to_i,
        :timeout => resource['health_check']['timeout'].to_i,
        :target => resource['target']
      )
    lb.instances.register( resource[:instances].map{|i| lookup(:aws_ec2_instance, i)} )
  end

  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end
