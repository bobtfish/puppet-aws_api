Facter.add(:aws_regions) do
  setcode do
    Facter.value(:aws_endpoints).keys
  end
end
