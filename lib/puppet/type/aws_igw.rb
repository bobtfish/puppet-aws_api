Puppet::Type.newtype(:aws_igw) do
  @doc = "Manage AWS internet gateways"
  newparam(:name)
  ensurable
  newproperty(:vpc) do
  end
  autorequire(:aws_vpc) do
    self[:vpc]
  end
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

