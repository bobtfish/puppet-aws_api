require 'puppetx/bobtfish/type_helpers'

Puppet::Type.newtype(:aws_elb) do
  @doc = "Manage AWS Elastic Load Balancers"
  newparam(:name)
  newproperty(:listeners, :parent => Puppetx::Bobtfish::UnorderedValueListProperty) do
    defaultto [{
      :port => 80,
      :protocol => 'http',
      :instance_port => 80,
      :instance_protocol => 'http',
    }]
  end
  ensurable
  newproperty(:subnets, :parent => Puppetx::Bobtfish::UnorderedValueListProperty) do
    defaultto []
  end
  autorequire(:aws_subnet) do
    self[:subnets]
  end
  newproperty(:security_groups, :parent => Puppetx::Bobtfish::UnorderedValueListProperty) do
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
  newproperty(:instances, :parent => Puppetx::Bobtfish::UnorderedValueListProperty) do
    defaultto []
  end
  autorequire(:aws_ec2_instance) do
    self[:instances]
  end
end

