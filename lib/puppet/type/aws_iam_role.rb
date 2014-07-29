Puppet::Type.newtype(:aws_iam_role) do
  @doc = "Manage AWS IAM Roles"
  newparam(:name)
  ensurable
  newproperty(:arn)
  newproperty(:assume_role_policy_document)
  newproperty(:service_principal)
end

