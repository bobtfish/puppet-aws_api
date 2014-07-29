Puppet::Type.newtype(:aws_igw) do
  @doc = "Manage AWS internet gateways"
  newparam(:name)
  ensurable
  newproperty(:vpc) do
  end
  autorequire(:aws_vpc) do
    self[:vpc]
  end
  newproperty(:tags)
  newparam(:route_to_main)
end

