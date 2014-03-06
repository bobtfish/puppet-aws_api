Puppet::Type.newtype(:aws_iam_group) do
  @doc = "Manage AWS IAM groups"
  newparam(:name)
  ensurable
  newproperty(:tags)
  newproperty(:policies)
  newproperty(:arn)
end

