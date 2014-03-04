Puppet::Type.newtype(:aws_subnet) do
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
  newproperty(:cidr)
  newproperty(:az)
  newproperty(:route_table)
  newproperty(:tags)
end

