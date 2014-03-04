Puppet::Type.newtype(:aws_cgw) do
  @doc = "Manage AWS customer gateways"
  newparam(:name)
  ensurable
  newproperty(:ip_address)
  newproperty(:bgp_asn)
  newproperty(:tags)
  newproperty(:region)
end

