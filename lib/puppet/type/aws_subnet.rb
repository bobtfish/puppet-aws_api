Puppet::Type.newtype(:aws_subnet) do
  @doc = "Manage AWS subnets"
  newparam(:name)
  ensurable
  newproperty(:vpc) do
  end
  autorequire(:aws_vpc) do
    self[:vpc]
  end
#  validate do
#    fail('vpc_id is required') if self[:vpc_id].nil?
#  end
  newproperty(:cidr)
  newproperty(:az)
  newparam(:unique_az_in_vpc) do
    desc "Auto-assign to an AZ not used by any other subnets in this VPC."
  end
  newproperty(:tags)
  # TODO: We are setting this, but it doesn't do anything in the backend
  newproperty(:route_table)
end

