Puppet::Type.newtype(:aws_ec2_instance) do
  @doc = "Manage AWS EC2 instances"
  newparam(:name)
  ensurable
  newproperty(:image_id)
  newproperty(:instance_type)
  newproperty(:iam_role)
  newproperty(:region)
  newproperty(:subnet)
  newproperty(:key_name)
  newproperty(:tags)
  newparam(:associate_public_ip_address)
  newproperty(:elastic_ip)
  newproperty(:block_device_mappings)
  newproperty(:security_groups)

  autorequire(:aws_subnet) do
    self[:subnet]
  end
  autorequire(:aws_iam_role) do
    self[:iam_role]
  end
  autorequire(:aws_security_group) do
    self[:security_groups]
  end
end

