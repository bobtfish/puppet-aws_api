# some very lazy smoke tests

$ensure = present


aws_vpc { 'test':
  region => 'us-west-2',
  cidr => '10.0.0.0/16',
  dhcp_options => 'test',
  ensure => $ensure
}

if $ensure != 'purged' {

  aws_dopts { 'test':
    tags => {
      test=> 'tag'
    },
    region => 'us-west-2',
  }


  aws_subnet {'main':
     vpc => 'test',
     cidr => '10.0.1.0/24'
  }

  # aws_iam_role {'test':}

  $ubuntu14 = {
      'us-west-2' => 'ami-e7b8c0d7', # Oregon
      'us-west-1' => 'ami-a7fdfee2', # Norcal
      'us-east-1' => 'ami-864d84ee', # Yes, Virginia
  }
  $ami = $ubuntu14['us-west-2']

  aws_ec2_instance {"node":
    image_id => $ami,
    instance_type => 't2.micro',
    subnet => 'main',
    key_name => 'puppet-test',
    user_data => "secret=blahblhburgertown",
    associate_public_ip_address => true,
  }

  aws_hosted_zone{ 'test2.com.':

  }

  aws_rrset {"SRV _sip._tcp.test2.com.":
    ttl => 123,
    zone => 'test2.com.',
    value => [
      '1 10 80 %{public_ip} '
    ],
    targets => [
      Aws_ec2_instance['node']
    ]
  }



}
