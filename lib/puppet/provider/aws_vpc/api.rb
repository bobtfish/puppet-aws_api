Puppet::Type.type(:aws_vps).provide(:api) do
  commands :aws => 'aws'
end

