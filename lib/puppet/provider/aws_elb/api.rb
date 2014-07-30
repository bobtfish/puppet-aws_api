require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))


Puppet::Type.type(:aws_elb).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods


  def self.new_from_aws(region_name, item)
    health_check = item.health_check
    target = health_check.delete(:target)

    new(
      :aws_item         => item,
      :name             => item.name,
      :listners         => item.listeners.map { |l| {
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
    )
  end
  def self.instances
    elb.load_balancers.collect { |item| new_from_aws(item) }
  end
  

  def create
    lb = elb.load_balancers.create(
      resource[:name],
      :listners => resource[:listners],
      :subnets => resource[:subnets].map{|s| lookup(:aws_subnet, s)},
      :security_groups => resource[:security_groups].map{|s| lookup(:aws_security_group, s)},
      :scheme => resource[:scheme],
    )
    lb.configure_health_check(resource[:health_check].merge(:target => resource[:target]))
  end
  
  def destroy
    @property_hash[:aws_item].delete
    @property_hash[:ensure] = :absent
  end
end

