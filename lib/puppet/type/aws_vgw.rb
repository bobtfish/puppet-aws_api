Puppet::Type.newtype(:aws_vgw) do
  @doc = "Manage AWS virtual private gateways"
  newparam(:name)
  ensurable
  newproperty(:tags)
  newproperty(:vpc)
  autorequire(:aws_vpc) do
   self[:vpc]
  end
  newproperty(:vpn_type) do
  end

  newparam(:availability_zone) do
  end
end

