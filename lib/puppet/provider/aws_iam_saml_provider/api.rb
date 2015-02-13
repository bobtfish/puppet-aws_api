require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_iam_saml_provider).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.new_from_aws(item)
    # extract the name of the saml_provider from the arn
    name = item[:arn].split('/')[-1]
    saml_metadata_document = iam.client.get_saml_provider(:saml_provider_arn => item[:arn]).saml_metadata_document
    new(
      :name             => name,
      :arn              => item[:arn],
      :saml_metadata_document => saml_metadata_document,
      :ensure           => :present
    )
  end
  def self.instances
    iam.client.list_saml_providers.saml_provider_list.collect { |item| new_from_aws(item) }
  end

  read_only(:arn, :saml_metadata_document)

  def create
    iam.client.create_saml_provider(
      :name => resource[:name],
      :saml_metadata_document => resource[:saml_metadata_document],
    )
  end

  def destroy
    iam.client.delete_saml_provider(
      :saml_provider_arn => arn
    )
    @property_hash[:ensure] = :absent
  end

end

