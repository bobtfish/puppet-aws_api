Puppet::Type.newtype(:aws_cgw) do
  @doc = "Manage AWS customer gateways"
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
  newproperty(:type)
  newproperty(:tags)
end

