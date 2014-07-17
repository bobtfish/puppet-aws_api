Puppet::Type.newtype(:aws_iam_user) do
  @doc = "Manage AWS IAM users"
  newparam(:name)
  ensurable
  newproperty(:path) do
    defaultto '/'
    validate do |v|
      fail("path must start and end with a /, not #{v}") unless v =~ /^\// and v =~ /\/$/
    end
  end
  newproperty(:arn)
  newproperty(:groups, :array_matching => :all)
end

