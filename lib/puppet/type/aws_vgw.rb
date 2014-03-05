Puppet::Type.newtype(:aws_vgw) do
  @doc = "Manage AWS virtual private gateways"
  newparam(:name)
  ensurable
  newproperty(:tags)
end

