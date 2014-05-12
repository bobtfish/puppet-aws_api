Puppet::Type.newtype(:aws_iam_group) do
  @doc = "Manage AWS IAM groups"
  newparam(:name)
  ensurable
  newproperty(:policies)
  newproperty(:arn)
  autorequire(:aws_credentials) do
    requires = []
    res = catalog.resources.find_all do |r|
      r.is_a?(Puppet::Type.type(:aws_credential))
    end
    res.each { |r| requires << r[:name] }
  end
  newproperty(:account)
end

