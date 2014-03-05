Puppet::Type.newtype(:aws_routetable) do
  @doc = "Manage AWS subnets"
  newparam(:name)
  ensurable
  newproperty(:subnets)
  newproperty(:routes)
  newproperty(:propagation_vgws)
  newproperty(:tags)
end

