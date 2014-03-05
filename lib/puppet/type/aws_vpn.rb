Puppet::Type.newtype(:aws_vpn) do
  @doc = "Manage AWS internet gateways"
  newparam(:name)
  ensurable
  newproperty(:vpc_id) do
  end
  autorequire(:aws_vpc) do
    self[:vpc_id]
  end
  newproperty(:vgw_id) do
  end
  autorequire(:aws_vgw) do
    self[:vgw_id]
  end
  validate do
  #  fail('vpc_id is required') if self[:vpc_id].nil?
  #  fail('vgw_id is required') if self[:vgw_id].nil?
  end
  newproperty(:type)
  newproperty(:routing)
  newproperty(:static_routes)
  newproperty(:tags)
end

