Puppet::Type.newtype(:aws_routetable) do
  @doc = "Manage AWS subnets"
  newparam(:name)
  ensurable
  newproperty(:vpc_id) do
  end
  autorequire(:aws_vpc) do
    self[:vpc_id]
  end
  validate do
    fail('vpc_id is required') if self[:vpc_id].nil?
  end
  newproperty(:subnets)
  newproperty(:routes)
  newproperty(:propagation_vgws)
  newproperty(:tags)
end

