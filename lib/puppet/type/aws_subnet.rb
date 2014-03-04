Puppet::Type.newtype(:aws_subnet) do
  @doc = "Manage AWS subnets"
  newparam(:name)
  ensurable
  newproperty(:vpc_id)
  newproperty(:cidr)
  newproperty(:az)
  newproperty(:route_table)
  newproperty(:tags)
end

