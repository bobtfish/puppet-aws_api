require 'pp'
require 'puppet'
module Puppet_X
  module Bobtfish
  end
end
# A custon property type for arrays of hashes with order-independent compare.
class Puppet_X::Bobtfish::ListOfHashesProperty < Puppet::Property
	def should_to_s(newvalue)
		PP.pp(newvalue.sort_by(&:to_a), "\n")
    end

    def is_to_s(currentvalue)
    	PP.pp(currentvalue.sort_by(&:to_a), "\n")
    end

    def should
    	return @should
    end

    def insync?(is)
    	@should.sort_by(&:to_a) == is.sort_by(&:to_a)
    end
end