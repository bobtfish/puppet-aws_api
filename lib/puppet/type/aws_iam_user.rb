Puppet::Type.newtype(:aws_iam_user) do
  @doc = "Manage AWS IAM users"
  newparam(:name)
  ensurable
  newproperty(:tags)
  newproperty(:arn)
  newproperty(:groups)
end

