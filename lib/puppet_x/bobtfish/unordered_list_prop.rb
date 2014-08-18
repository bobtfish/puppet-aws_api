require 'pp'
require 'puppet'
module Puppet_X
  module Bobtfish
  end
end
# A custon property type for arrays of hashes with order-independent compare.
class Puppet_X::Bobtfish::UnorderedValueListProperty < Puppet::Property
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
