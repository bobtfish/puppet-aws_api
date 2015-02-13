Puppet::Type.newtype(:aws_iam_saml_provider) do
  @doc = "Manage AWS IAM SAML Providers"
  newparam(:name)
  ensurable
  newproperty(:arn)
  newproperty(:saml_metadata_document)
end

