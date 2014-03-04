Puppet::Type.type(:aws_vpc).provide(:api) do
  commands :aws => 'aws'
end

