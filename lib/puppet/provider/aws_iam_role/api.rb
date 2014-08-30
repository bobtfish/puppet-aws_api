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

    policy_document = begin
      JSON.parse(URI.decode(
        iam.client.get_role_policy(
          :role_name => aws_item[:role_name],
          :policy_name => self.role_policy_name(aws_item[:role_name])
        ).data[:policy_document]
      ))
    rescue AWS::IAM::Errors::NoSuchEntity => e
      nil
    end

    init :policy_document, policy_document
    init :assume_role_policy_document, JSON.parse(URI.decode(aws_item[:assume_role_policy_document]))
  end


  def service_principal
    @property_hash[:assume_role_policy_document]['Statement'][0]['Principal']['Service'] rescue nil
  end

  def service_principal=(service)
    @property_hash[:assume_role_policy_document] ||= service_tempalte(service)
    @property_hash[:assume_role_policy_document]['Statement']['Principal']['Service'] = service
    @property_flush[:assume_role_policy_document] = @property_hash[:assume_role_policy_document]
  end

  def permissions
    return nil unless @property_hash[:policy_document]
    @property_hash[:policy_document]['Statement']
  end

  def permissions=(statements)
    @property_hash[:policy_document] = {
      'Version' => '2012-10-17',
      'Statement' => statements
    }
    @property_flush[:policy_document] = @property_hash[:policy_document]
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

    resource[:assume_role_policy_document] ||= service_tempalte(resource[:service_principal])

    flushing :ensure => :create do

      # Create the role itself
      role = iam.client.create_role(
        :role_name => resource[:name],
        :assume_role_policy_document => JSON.dump(resource[:assume_role_policy_document]),
      ).role

      @property_hash[:aws_item] = role # 'tis our aws_item

      # Since we just posted the assume_role_policy_document, we no longer need to flush it
      @property_flush[:assume_role_policy_document].delete

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
    end

    flushing :assume_role_policy_document do |doc|
      iam.client.update_assume_role_policy(
        :role_name => resource[:name],
        :policy_document => doc
      )
    end

    flushing :policy_document do |doc|
      iam.client.put_role_policy(
        :role_name => resource[:name],
        :policy_name => self.role_policy_name,
        :policy_document => JSON.dump(doc)
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

