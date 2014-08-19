require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'puppet_x', 'bobtfish', 'unordered_list_prop.rb'))

Puppet::Type.newtype(:aws_elb) do
  @doc = "Manage AWS Elastic Load Balancers"
  newparam(:name)
  newproperty(:listeners, :parent => Puppet_X::Bobtfish::UnorderedValueListProperty) do
    defaultto [{
      :port => 80,
      :protocol => 'http',
      :instance_port => 80,
      :instance_protocol => 'http',
    }]
  end
  ensurable
  newproperty(:subnets, :parent => Puppet_X::Bobtfish::UnorderedValueListProperty) do
    defaultto []
  end
  autorequire(:aws_subnet) do
    self[:subnets]
  end
  newproperty(:security_groups, :parent => Puppet_X::Bobtfish::UnorderedValueListProperty) do
    defaultto []
  end
  autorequire(:aws_security_group) do
    self[:security_groups]
  end
  newproperty :scheme do
    newvalue 'internet-facing'
    newvalue 'private'
  end
  newproperty(:health_check) do
    defaultto({
      "healthy_threshold" => "10",
      "unhealthy_threshold" => "2",
      "interval" => "30",
      "timeout" => "5"
    })
  end
  newproperty(:target) do
    defaultto "HTTP:80/"
  end
  newproperty(:instances, :parent => Puppet_X::Bobtfish::UnorderedValueListProperty) do
    defaultto []
  end
  autorequire(:aws_ec2_instance) do
    self[:instances]
  end
end

