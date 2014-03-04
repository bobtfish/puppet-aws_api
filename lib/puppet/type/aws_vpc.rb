Puppet::Type.newtype(:aws_vpc) do
  @doc = "Manage AWS vpcs"
  newparam(:name)
  ensurable
  newproperty(:region)
  newproperty(:cidr)
  newproperty(:dhcp_options_id)
  newproperty(:instance_tenancy)
end

