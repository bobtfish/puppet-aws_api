require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'puppet_x', 'bobtfish', 'ec2_api.rb'))

Puppet::Type.type(:aws_iam_role).provide(:api, :parent => Puppet_X::Bobtfish::Ec2_api) do
  mk_resource_methods

  def self.new_from_aws(item)
    new(
      :name             => item[:role_name],
      :id               => item[:id],
      :arn              => item[:arn],
      :assume_role_policy_document =>  JSON.parse(URI.decode(item[:assume_role_policy_document])),
      :ensure           => :present
    )
  end
  def self.instances
    iam.client.list_roles.roles.collect { |item| new_from_aws(item) }
  end
  [:arn, :name, :assume_role_policy_document].each do |ro_method|
    define_method("#{ro_method}=") do |v|
      fail "Cannot manage #{ro_method} is read-only once an IAM role is created"
    end
  end

  def service_principal
    assume_role_policy_document['Statement'][0]['Principal']['Service'] rescue nil
  end

  def service_principal=(service)
    assume_role_policy_document ||= service_tempalte(service)
    assume_role_policy_document['Statement']['Principal']['Service'] = service
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

