require 'puppetx/bobtfish/type_helpers'

Puppet::Type.newtype(:aws_rds_instance) do
  @doc = "Manage AWS RDS instances"
  newparam(:name)
  ensurable
  newproperty(:allocated_storage) do
    include Puppetx::Bobtfish::EnsureIntValue
    include Puppetx::Bobtfish::RequiredValue
    desc "The amount of storage (in gigabytes) to be initially allocated for the database instance."
  end
  newproperty(:db_instance_class) do
    include Puppetx::Bobtfish::RequiredValue
    newvalues /^db\.t\d\.\w+$/
  end
  newproperty(:engine) do
    defaultto 'mysql'
    newvalues *%W(mysql oracle-se1 oracle-se oracle-ee sqlserver-ee sqlserver-se sqlserver-ex sqlserver-web postgres)
  end
  newproperty(:engine_version)

  newproperty(:master_username) do
    include Puppetx::Bobtfish::RequiredValue
  end

  newparam(:master_user_password) do
    include Puppetx::Bobtfish::RequiredValue
    validate do |value|
      unless value =~ /^[^\/@]+$/
        raise ArgumentError, "Password can be any printable character except @ or /."
      end
      # when value isn't explicitly given, assume default
      # TODO: this is not strictlys peaking correct as it can depend on the parse-order
      # of the aprameters in the pp file - better solution is to perform inter-dependent
      # param setup at the type level if possible (is it?)
      case (resource[:engine] || 'mysql').to_s
      when 'mysql'
        unless (8..41).include? value.size
          raise ArgumentError, "MySQL passwords must contain from 8 to 41 characters."
        end
      when /^oracle/
        unless (8..30).include? value.size
          raise ArgumentError, "Oracle passwords must contain from 8 to 30 characters."
        end
      when /^sqlserver/
        unless (8..128).include? value.size
          raise ArgumentError, "SQL Server passwords must contain from 8 to 128 characters."
        end
      end

    end
  end
  newproperty(:multi_az, :boolean => true)

  newparam(:publicly_accessible, :boolean => true)

  newproperty(:subnets) do
    include Puppetx::Bobtfish::SortedDeepCompare
    include Puppetx::Bobtfish::RequiredValue
    # (making this optional would require an alternate mechanism for dealing with regions)

    validate do |value|
      # When passed array values puppet always calls validate (and munge) separately for
      # each array value.
      # This cannot be turned off.
      # And is RIDICULOUS.
      value = @shouldorig if @shouldorig
      unless value.is_a?(Array) && value.size >= 2
        raise ArgumentError, "RDS instance must have at least 2 subnets across different AZs"
      end
    end
  end
  autorequire(:aws_subnet) do
    self[:subnets]
  end

  newproperty(:security_groups) do
    include Puppetx::Bobtfish::SortedDeepCompare
    defaultto []
  end
  autorequire(:aws_security_group) do
    self[:security_groups]
  end

  newproperty(:endpoint) do
    include Puppetx::Bobtfish::ReadOnlyProperty
    desc "Read-only: endpoint DNS name for this DB"
  end
end

