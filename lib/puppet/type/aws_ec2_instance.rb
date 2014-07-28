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

  autorequire(:aws_subnet) do
    self[:subnet]
  end
  autorequire(:aws_iam_role) do
    self[:iam_role]
  end
end

