require 'pp'

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

    module AZValidation
      # TODO: ... autoload region through provider
      def unsafe_validate(value)
        super
        azs = function_aws_azs(resource[:region])
        unless azs.include? value
          raise ArgumentError, "#{value} is not a valid AZ for the current region. (Valid AZs for region #{resource[:region]} are: #{azs})"
        end
      end
    end

    module Purgable
      def self.included(other)
        other.defaultvalues
        other.newvalue(:purged) do
          provider.ensure = :purged
        end

        def insync?(is)
          super(is) or (should == :purged and is == :absent)
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

    module PermissionCollection
      def self.included(other)
        other.desc("An array of rules where each rule is a hash with the follwing keys: " +
          "'protocol' => Either a protocol name such as 'tcp' or 'udp' (a complete " +
          "list is available at http://www.iana.org/assignments/protocol-numbers/protocol-numbers.xml)" +
          " or the string 'any'. " +
          "'ports' =>  A port number or a range or a range of ports as a 2-element array - e.g." +
          " 80 or [3000, 3030]. " +
          "'sources' => An array of sources this rule applies to, each of whcih  can be either " +
          "a CIDR string (e.g. '10.0.0.1/16'), or the name of another security group."
        )
      end
    end

    def unsafe_validate(value)
      unless value.is_a? Array
        raise ArgumentError, "#{resource} #{name} must be an array of security rule hashes - got: #{value.inspect}"
      end
      values.each do |val|
        validate_rule(val)
      end
    end

    def validate_rule(rule)
      if rule.keys.sort != %w(protocol ports sources).sort
        raise ArgumentError, "Security rules must have exactly 3 keys: protocol, ports and sources - got #{rule.keys}"
      end
      unless rule['protocol'] =~ /^\w+$/
        raise ArgumentError, "Security rule protocol must be an IANA string or 'any' - got #{rule['protocol'].inspect}"
      end

      if rule[:ports].is_a? Array
        unless rule[:ports].size == 2
          raise ArgumentError, "Security rule port range must given as an array with exactly 2 elements - got: #{rule['ports']}"
        end
        unless rule[:ports].all?{ |p| p =~ /^\d+$/ }
          raise ArgumentError, "Security rule port range must be an array of integers - got: #{rule[:ports]}"
        end
        if rule[:ports][0].to_i > rule[:ports][1].to_i
          raise ArgumentError, "Security rule port range must go be given from high to low - got: #{rule[:ports]}"
        end
      else
        unless rule[:ports] =~ /^\d+$/
          raise ArgumentError, "Security rule port value must be an integer - got: #{rule[:ports]}"
        end
      end

      unless rule[:sources].is_a? Array
        raise ArgumentError, "Security rule sources must be an array - got: #{rule[:sources]}"
      end

      unless rule[:sources].all? {|src| src.is_a? String}
        raise ArgumentError, "Each source for a security rule must be a string (either a CIDR or the name of another security group."
      end
    end
  end
end


# A horrible hack
# see notes for RequiredValue.suspend
class Puppet::Indirector::Indirection
  alias_method :original_search, :search
  def search(*args)
    Puppetx::Bobtfish::RequiredValue.suspend {
      original_search(*args)
    }
  end
end
