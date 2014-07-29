Puppet::Type.newtype(:aws_security_group) do
  @doc = "Manage AWS Security Groups"
  newparam(:name)
  ensurable
  newproperty(:description)
  newproperty(:vpc)
  autorequire(:aws_vpc) do
    self[:vpc]
  end
  newproperty(:tags)
  newproperty(:authorize_ingress)
  newproperty(:authorize_egress)
end

