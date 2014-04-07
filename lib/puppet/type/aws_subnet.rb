Puppet::Type.newtype(:aws_subnet) do
  @doc = "Manage AWS subnets"
  newparam(:name)
  ensurable
  newproperty(:vpc) do
  end
  autorequire(:aws_vpc) do
    self[:vpc]
  end
#  validate do
#    fail('vpc_id is required') if self[:vpc_id].nil?
#  end
  newproperty(:cidr)
  newproperty(:az)
  newproperty(:route_table)
  newproperty(:tags)
  autorequire(:aws_credentials) do
    requires = []
    res = catalog.resources.find_all do |r|
      r.is_a?(Puppet::Type.type(:aws_credential))
    end
    res.each { |r| requires << r[:name] }
  end
  newparam(:account)
end

