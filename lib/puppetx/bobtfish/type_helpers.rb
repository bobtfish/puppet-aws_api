module Puppetx
  module Bobtfish
    class ReadOnlyPropertyError < Exception
    end
    module ReadOnlyProperty
      def should=(value)
          raise ReadOnlyPropertyError.new("Can't set read-only property #{name}")
      end
      def insync?(is)
          true
      end
    end

    module SortedDeepCompare
      def should_to_s(newvalue)
        PP.pp(deep_sort(newvalue), "\n")
      end

      def is_to_s(currentvalue)
        PP.pp(deep_sort(currentvalue), "\n")
      end

      def should
        return @should
      end

      def insync?(is)
        deep_sort(should) == deep_sort(is)
      end

      private
      def deep_sort(value)
        case value
        when Hash
          sorted_hsh = {}
          value.each do |k, v|
            sorted_hsh[k] = deep_sort(v)
          end
          sorted_hsh
        when Array
          value.sort_by(&method(:sort_key)).map(&method(:deep_sort))
        else
          value
        end
      end

      def sort_key(value)
        case value
        when Hash
          value.to_a
        else
          value
        end
      end
    end

    module EnsureIntValue
      def unsafe_validate(value)
        unless value =~ /^\d+$/
          raise ArgumentError, "#{resource} #{name} must be a valid integer, got: #{value.inspect}"
        end
      end

      def unsafe_munge(value)
        value.to_i
      end

    end

    module EnsureHashValue
      def unsafe_validate(value)
        unless value.is_a? Hash
          raise ArgumentError, "#{resource} #{name} must be a Hash, got: #{value.inspect}"
        end
      end

      def should
        # the raw value please
        @should
      end

      def default
        {}
      end
    end

    module RequiredValue
      class ValueNotGiven
      end

      def default
        ValueNotGiven
      end

      # suspend setters - work around for RAL search forcefully instantiating
      # default values even though no types should even be involved
      @@suspended = false
      def self.suspend
        @@suspended = true
        returning = yield
        @@suspended = false
        returning
      end

      def value=(value)
        super(value) unless @@suspended
      end

      def unsafe_validate(value)
        if value == ValueNotGiven
          raise ArgumentError, "#{resource} requires a #{name}!"
        end
        super
      end
    end

    module RegionValidation
      def unsafe_validate(value)
        super
        unless Facter.value(:aws_regions).include? value
          raise ArgumentError, "#{value} is not a valid region. (Valid regions are: #{Facter.value(:aws_regions)})"
        end
      end
    end

    module Purgable
      def self.included(other)
        other.defaultvalues
        other.newvalue(:purged) do
          resource.provider.purge
        end
      end
    end

    module CIDRValidation
      # courtesy of http://blog.markhatton.co.uk/2011/03/15/regular-expressions-for-ip-addresses-cidr-ranges-and-hostnames/
      PATTERN = /^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\/(\d|[1-2]\d|3[0-2]))$/
      # note that AWS VPCs can't work with IPV6 ranges, so the above pattern shoudl suffice should suffice

      def unsafe_validate(value)
        super
        unless value =~ PATTERN
          raise ArgumentError, "#{value} is not a valid IPv4 CIDR"
        end
      end
    end

  end
end


# A horrible hack
class Puppet::Indirector::Indirection
  alias_method :original_search, :search
  def search(*args)
    Puppetx::Bobtfish::RequiredValue.suspend {
      original_search(*args)
    }
  end
end
