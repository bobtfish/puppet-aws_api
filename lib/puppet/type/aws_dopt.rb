Puppet::Type.newtype(:aws_dopts) do
  @doc = "Manage AWS DHCP Options sets"
  newparam(:name)
  ensurable
  newproperty(:tags)
end

