Puppet::Type.type(:aws_subnet).provide(:api) do
  commands :aws => 'aws'
end

