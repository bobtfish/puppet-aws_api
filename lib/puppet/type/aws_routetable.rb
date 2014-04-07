Puppet::Type.newtype(:aws_routetable) do
  @doc = "Manage AWS route tables"
  newparam(:name)
  ensurable
  newproperty(:vpc)
  newproperty(:subnets)
  newproperty(:routes)
  newproperty(:main) do
    newvalue 'true'
    newvalue 'false'
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

