Puppet::Type.newtype(:aws_iam_group) do
  @doc = "Manage AWS IAM groups"
  newparam(:name)
  ensurable
  newproperty(:policies)
  newproperty(:arn)
end

