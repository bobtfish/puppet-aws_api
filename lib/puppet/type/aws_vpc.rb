Puppet::Type.newtype(:aws_vpc) do
  @doc = "Manage AWS vpcs"
  newparam(:name)
  ensurable
  newproperty(:id)
  newproperty(:region)
  newproperty(:cidr)
  newproperty(:dhcp_options)
  autorequire(:aws_dopts) do
    self[:dhcp_options]
  end
  newproperty(:instance_tenancy)
  newproperty(:tags)
end

