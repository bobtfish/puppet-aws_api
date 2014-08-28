require 'rubygems'
require 'puppet'

module Puppetx
  module Bobtfish
    # A custon property type for arrays of hashes with order-independent compare.
    class ReadOnlyPropertyError < Exception
    end
    class ReadOnlyProperty < ::Puppet::Property
      def should=(value)
          raise ReadOnlyPropertyError.new("Can't set read-only property #{name}")
      end
      def insync?(is)
          true
      end
    end

    # A custon property type for arrays of hashes with order-independent compare.
    class UnorderedValueListProperty < ::Puppet::Property
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
      def self.included(prop)
        prop.validate do |value|
          unless value =~ /^\d+$/
            raise ArgumentError, "TTL must be a valid integer, got: #{value.inspect}"
          end
        end
        prop.munge do |value|
          value.to_i
        end
      end
    end



    module RequiredValue
      class ValueNotGiven
      end
      def self.included(prop)
        prop.defaultto ValueNotGiven
      end

      def unsafe_validate(value)
        if value == ValueNotGiven
          raise ArgumentError, "#{resource} requires a  #{name}!"
        end
      end
    end

  end
end



