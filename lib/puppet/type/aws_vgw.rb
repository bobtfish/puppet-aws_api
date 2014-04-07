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
  newproperty(:availability_zone) do
  end
  autorequire(:aws_credentials) do
    requires = []
    res = catalog.resources.find_all do |r|
      r.is_a?(Puppet::Type.type(:aws_credential))
    end
    res.each { |r| requires << r[:name] }
  end
  newparam(:account)
end

