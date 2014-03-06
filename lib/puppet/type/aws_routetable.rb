Puppet::Type.newtype(:aws_routetable) do
  @doc = "Manage AWS route tables"
  newparam(:name)
  ensurable
  newproperty(:vpc)
  newproperty(:subnets)
  newproperty(:routes)
  newproperty(:tags)
end

