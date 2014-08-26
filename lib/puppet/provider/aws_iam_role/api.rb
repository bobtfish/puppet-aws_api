require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'aws_api.rb'))

Puppet::Type.type(:aws_iam_role).provide(:api, :parent => Puppet_X::Bobtfish::Aws_api) do
  mk_resource_methods

  find_region_from nil

  def self.new_from_aws(item)
    role_policies = begin
      JSON.parse(URI.decode(
        iam.client.get_role_policy(
          :role_name => item[:role_name],
          :policy_name => self.role_policy_name(item[:role_name])
        ).data[:policy_document]
      ))
    rescue AWS::IAM::Errors::NoSuchEntity => e
      nil
    end

    new(
      :name             => item[:role_name],
      :id               => item[:id],
      :arn              => item[:arn],
      :assume_role_policy_document =>  JSON.parse(URI.decode(item[:assume_role_policy_document])),
      :role_policies    => role_policies,
      :ensure           => :present
    )
  end
  def self.instances
    iam.client.list_roles.roles.collect { |item| new_from_aws(item) }
  end

  read_only(:arn, :service_principal, :assume_role_policy_document)

  def service_principal
    @property_hash[:assume_role_policy_document]['Statement'][0]['Principal']['Service'] rescue nil
  end

  def service_principal=(service)
    assume_role_policy_document ||= service_tempalte(service)
    assume_role_policy_document['Statement']['Principal']['Service'] = service
    iam.client.update_assume_role_policy(
      :role_name => @property_hash[:name],
      :policy_document => assume_role_policy_document
    )
  end

  def permissions
    return nil unless @property_hash[:role_policies]
    @property_hash[:role_policies]['Statement']
  end

  def permissions=(statements)
    iam.client.put_role_policy(
      :role_name => @property_hash[:name],
      :policy_name => self.role_policy_name,
      :policy_document => JSON.dump(
        'Version' => '2012-10-17',
        'Statement' => statements
      )
    )
  end

  def create
    resource[:assume_role_policy_document] ||= service_tempalte(resource[:service_principal])
    iam.client.create_role(
      :role_name => resource[:name],
      :assume_role_policy_document => JSON.dump(resource[:assume_role_policy_document]),
    )
    iam.client.create_instance_profile(
      :instance_profile_name => resource[:name]
    )
    iam.client.add_role_to_instance_profile(
      :instance_profile_name => resource[:name],
      :role_name => resource[:name]
    )
    self.permissions=resource[:permissions]
  end
  def destroy
    iam.client.remove_role_from_instance_profile(
      :instance_profile_name => resource[:name],
      :role_name => resource[:name]
    )
    iam.client.delete_instance_profile(
      :instance_profile_name => resource[:name]
    )
    iam.client.delete_role(
      :role_name => resource[:name]
    )
    @property_hash[:ensure] = :absent
  end



  def role_policy_name
    self.class.role_policy_name @property_hash[:name]
  end

  def self.role_policy_name(name)
    "#{name}_role_policy"
  end

  private

  def service_tempalte(service)
    return {'Statement' => [
      {
        'Action' => 'sts:AssumeRole',
        'Effect' => 'Allow',
        'Principal' => {'Service' => service},
        'Sid' => ''
      }], 'Version' => '2012-10-17'}
  end
end

