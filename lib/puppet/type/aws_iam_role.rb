require 'puppetx/bobtfish/type_helpers'
Puppet::Type.newtype(:aws_iam_role) do
  @doc = "Manage AWS IAM Roles"
  newparam(:name)
  ensurable

  newproperty(:service_principal) do
  	desc "Name of the service principal that this role will be used with - e.g. 'ec2.amazonaws.com'"
  end

  newproperty(:permissions, :parent => Puppetx::Bobtfish::UnorderedValueListProperty) do
    defaultto []
    desc 'A list of AWS IAM permissions statements. Assumes a default policy name of "${name}_role_policy". Other policies are ignored.'
  end

end

