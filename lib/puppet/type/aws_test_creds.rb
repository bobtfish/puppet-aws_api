Puppet::Type.newtype(:aws_test_creds) do
  @doc = "Run tests against credential backend :)"
  newparam(:name)
  autorequire(:aws_credentials) do
    requires = []
    res = catalog.resources.find_all do |r|
      r.is_a?(Puppet::Type.type(:aws_credential))
    end
    res.each { |r| requires << r[:name] }
  end
  newproperty(:account)
end

