require 'puppet'
module Puppet_X
  module Bobtfish
  end
end
# A custon property type for arrays of hashes with order-independent compare.
class Puppet_X::Bobtfish::ReadOnlyProperty < Puppet::Property
    class ReadOnlyPropertyError < Exception
    end
    def should=(value)
        raise ReadOnlyPropertyError.new("Can't set read-only property #{name}")
    end
    def insync?(is)
        true
    end
end
