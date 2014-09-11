require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_iam_role).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
   flushing_resource_methods :read_only => [
    :arn, :service_principal, :assume_role_policy_document]


  find_region_from nil

  primary_api :iam

  def self.aws_items_for_region(region)
    iam.client.list_roles.roles
  end

  def self.get_ensure_state(aws_item)
    # Since we have ot use the "raw" API, aws_item is just a Hash
    if !aws_item.nil? and !aws_item.empty?
      :present
    else
      :absent
    end
  end

  def init_property_hash
    super
    map_init(:name => :role_name)

    @policy_document = begin
      JSON.parse(URI.decode(
        iam.client.get_role_policy(
          :role_name => aws_item[:role_name],
          :policy_name => self.role_policy_name,
        ).data[:policy_document]
      ))
    rescue AWS::IAM::Errors::NoSuchEntity => e
      nil
    end
    init :permissions, policy_document['Statement']

    @assume_role_policy_document = JSON.parse(URI.decode(aws_item[:assume_role_policy_document]))
    init :service_principal, assume_role_policy_document['Statement'][0]['Principal']['Service']
  end

  def policy_document
    @policy_document ||= {
      'Version' => '2012-10-17',
      'Statement' => @property_hash[:permissions]
    }
  end

  def assume_role_policy_document
    @assume_role_policy_document ||= {'Statement' => [{
      'Action' => 'sts:AssumeRole',
      'Effect' => 'Allow',
      'Principal' => {'Service' => @property_hash[:service_principal]},
      'Sid' => ''
    }], 'Version' => '2012-10-17'}
  end


  def flush_when_ready
    flushing :ensure => :absent do
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
      return # don't continue flushing
    end

    self.assume_role_policy_document['Statement'][0]['Principal']['Service'] = resource[:service_principal]
    self.policy_document['Statement'] = resource[:permissions]

    flushing :ensure => :present do

      # Create the role itself
      role = iam.client.create_role(
        :role_name => resource[:name],
        :assume_role_policy_document => JSON.dump(self.assume_role_policy_document),
      ).role

      @property_hash[:aws_item] = role # 'tis our aws_item

      # Now the instance profile
      profile = iam.client.create_instance_profile(
        :instance_profile_name => resource[:name]
      ).instance_profile

      update_profile_cache(profile)

      # Now kiss!
      iam.client.add_role_to_instance_profile(
        :instance_profile_name => resource[:name],
        :role_name => resource[:name]
      )

      also_flush :permissions
    end

    flushing :service_principal do |doc|
      iam.client.update_assume_role_policy(
        :role_name => resource[:name],
        :policy_document => self.assume_role_policy_document,
      )
    end

    flushing :permissions do |perms|
      iam.client.put_role_policy(
        :role_name => resource[:name],
        :policy_name => self.role_policy_name,
        :policy_document => JSON.dump(self.policy_document)
      )
    end
  end

  def role_policy_name
    "#{@property_hash[:name]}_role_policy"
  end


  private

  def update_profile_cache(profile)
    self.class.instance_profiles[profile[:instance_profile_id]] = profile
  end

end

