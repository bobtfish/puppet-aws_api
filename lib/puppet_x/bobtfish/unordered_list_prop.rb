require 'pp'
require 'puppet'
module Puppet_X
  module Bobtfish
  end
end
# A custon property type for arrays of hashes with order-independent compare.
class Puppet_X::Bobtfish::UnorderedValueListProperty < Puppet::Property
	def should_to_s(newvalue)
		PP.pp(newvalue.sort_by(&method(:sort_key)), "\n")
    end

    def is_to_s(currentvalue)
    	PP.pp(currentvalue.sort_by(&method(:sort_key)), "\n")
    end

    def should
    	return @should
    end

    def insync?(is)
    	@should.sort_by(&method(:sort_key)) == is.sort_by(&method(:sort_key))
    end
    private
    def sort_key(value)
        case value
        when Hash
            value.to_a
        else
            value
        end
    end
end