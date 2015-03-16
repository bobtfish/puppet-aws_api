Puppet::Type.newtype(:aws_subnet) do
  @doc = "Manage AWS subnets"
  newparam(:name)
  ensurable
  newproperty(:vpc)
  autorequire(:aws_vpc) { self[:vpc] }
  newproperty(:cidr)
  newproperty(:az)
  newparam(:unique_az_in_vpc) do
    desc "Auto-assign to an AZ not used by any other subnets in this VPC."
  end
  newproperty(:tags)
  newproperty(:route_table)
end
