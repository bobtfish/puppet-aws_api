require 'puppetx/bobtfish/type_helpers'

Puppet::Type.newtype(:aws_ec2_instance) do
  @doc = "Manage AWS EC2 instances"
  newparam(:name)
  ensurable

  newproperty(:image_id) do
    include Puppetx::Bobtfish::RequiredValue
  end

  newproperty(:instance_type) do
    include Puppetx::Bobtfish::RequiredValue
  end

  newproperty(:iam_role)

  newproperty(:subnet) do
    include Puppetx::Bobtfish::RequiredValue
  end

  newproperty(:key_name) do
    include Puppetx::Bobtfish::RequiredValue
  end

  newproperty(:tags)

  newparam(:associate_public_ip_address)

  newproperty(:elastic_ip)

  newproperty(:block_device_mappings, :parent => Puppetx::Bobtfish::UnorderedValueListProperty)

  newproperty(:security_groups, :parent => Puppetx::Bobtfish::UnorderedValueListProperty) do
    defaultto []
  end

  autorequire(:aws_subnet) do
    self[:subnet]
  end
  autorequire(:aws_iam_role) do
    self[:iam_role]
  end
  autorequire(:aws_security_group) do
    self[:security_groups]
  end

  newproperty(:public_ip_address, :parent => Puppetx::Bobtfish::ReadOnlyProperty) do
    desc "Read-only: public ip of machine"
  end
end

