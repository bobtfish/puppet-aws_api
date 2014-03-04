Puppet::Type.newtype(:aws_igw) do
  @doc = "Manage AWS internet gateways"
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
  newproperty(:tags)
end

