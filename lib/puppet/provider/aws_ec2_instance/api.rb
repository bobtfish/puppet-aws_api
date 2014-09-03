require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_ec2_instance).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
  include Puppetx::Bobtfish::TaggableProvider

  flushing_resource_methods :read_only => [
    # these properties cannot be changed without terminating or stoping the instance,
    # so we don't support changing them for the moment
    :image_id,
    :instance_type,
    :iam_role,
    :region,
    :subnet,
    :key_name,
    :block_device_mappings,
  ]

  find_region_from :aws_subnet, :subnet

  primary_api :ec2, :collection => :instances

  ensure_from_state(
    :pending => :running,
    :running => :present,
    :shutting_down => :terminated,
    :terminated => :absent,
    :stopping => :stopped,
    :stopped => :stopped, # :stopped is a valid ec2-specific ensure state for the puppet type
    &:status # equivalent to passing in the block {|aws_item| aws_item.status }
  )


  def init_property_hash
    super # let taggable do its thing

    # some properties we can just assign directly from aws_item:
    map_init(
      :image_id,
      :instance_type,
      :public_ip_address
    )

    # these rest are more complicated

    init :subnet, aws_item.subnet.tags['Name'] if aws_item.subnet
    init :key_name, aws_item.key_pair.name
    init :elastic_ip, !!aws_item.elastic_ip
    init :block_device_mappings, (aws_item.block_device_mappings.to_h.map { |mount, dev|
      {
        'device_name' => mount,
        'ebs' => {
          'volume_size' => dev.volume.size.to_s,
          'delete_on_termination' => dev.delete_on_termination,
          'volume_type' => if dev.volume.iops then 'io1' else 'standard' end # i think this is right?
        }
      }
    })
    init :security_groups, aws_item.security_groups.collect{ |sg| "#{sg.vpc.tags['Name']}:#{sg.name}"}

    profile = self.class.instance_profiles[aws_item.iam_instance_profile_id]
    init :iam_role, profile[:instance_profile_name] if profile

  end

  @@default_timeout = 300 # ec2 instances can be a bit slow to start at times

  def flush_when_ready
    flushing :ensure => :absent do
      eip = aws_item.elastic_ip

      volumes = aws_item.attachments.map do |mnt, att|
        att.delete(:force => true)
        att.volume
      end

      aws_item.delete

      # Avoid squating on current resource name while terminated
      aws_item.tags['Name'] = @property_hash[:name] + "-terminated"

      wait_until {aws_item.status == :terminated }

      volumes.each do |vol|
        if vol.state == :deleting or vol.state == :deleted
          wait_until { vol.state == :deleted }
        else
          wait_until { vol.state == :available || vol.state == :error }
          vol.delete
        end
      end

      eip.delete
      return # don't do any further flushing
    end

    flushing :ensure => :present do

      instance_config = {
        :image_id             => resource[:image_id],
        :instance_type        => resource[:instance_type],
        :subnet               => lookup(:aws_subnet, resource[:subnet]).aws_item,
        :key_name             => resource[:key_name],
        :associate_public_ip_address => resource[:associate_public_ip_address],
        :user_data            => resource[:user_data],
      }
      if resource[:iam_role]
        profile = iam.client.get_instance_profile(
          :instance_profile_name => resource[:iam_role]
        )
        instance_config[:iam_instance_profile] = profile[:instance_profile][:arn]
      end

      if block_devices = resource[:block_device_mappings]
        block_devices.each_with_index do |dev, i|

          if dev['ebs'] and dev['ebs']['volume_size']
            # Fun fact: puppet resources aren't aware of ints
            dev['ebs']['volume_size'] = dev['ebs']['volume_size'].to_i
          end
          # Just auto-name, we can't actually get this name back and it pretty much
          # has to follow this pattern anyway
          dev['virtual_name'] = "ephemeral#{i}"
        end
        instance_config[:block_device_mappings] = block_devices
      end


      instance = collection.create(instance_config)

      # tag devices
      instance.block_devices.each do |dev|
        if dev[:ebs] and dev[:ebs][:volume_id]
          name = dev[:device_name].sub(/^\/dev\//, '')
          ec2.volumes[dev[:ebs][:volume_id]].add_tag('Name', :value => "#{resource[:name]}-#{name}")
        end
      end

      also_flush(:security_groups, :elastic_ip)

      instance # this becomes aws_item
    end

    flushing :security_groups do |sgs|
      aws_item.client.modify_instance_attribute(
        :instance_id => aws_item.id,
        :groups => sgs.collect {|sg| lookup(:aws_security_group, sg).aws_item.id }
      )
    end

    flushing :elastic_ip => true do
      eip = ec2.elastic_ips.create(:vpc => true)
      wait_until { eip.exists? }
      aws_item.associate_elastic_ip(eip)
    end

    flushing :elastic_ip => false do
      eip = aws_item.elastic_ip
      eip.dissasociate
      eip.release
    end

    super # taggable again
  end

  def substitutions
    {
      :public_ip => aws_item.public_ip_address,
      :cname => aws_item.public_dns_name
    }
  end



end

