require 'puppetx/bobtfish/aws_api'

Puppet::Type.type(:aws_s3_bucket).provide(:api, :parent => Puppetx::Bobtfish::Aws_api) do
  flushing_resource_methods :read_only => [:region]

  find_region_from :region

  primary_api :s3, :collection => :buckets

  def init_property_hash
    super
    map_init(:name)
  end

  def substitutions
    {
      :url => aws_item.url
    }
  end

  # TODO: use flush (though this works fine)

  def create
    s3_region_string = if resource[:region] == 'us-east-1'
      # yep - this is a special problem with the S3 bucket API alone
      s3(resource[:region]).buckets.create(resource[:name])
    else
      s3(resource[:region]).buckets.create(resource[:name],
        :location_constraint => resource[:region]
      )
    end
  end
  def destroy
    aws_item.delete
    @property_hash[:ensure] = :absent
  end
  def purge
    aws_item.delete!
    @property_hash[:ensure] = :purged
  end

end

