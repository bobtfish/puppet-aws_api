# some very lazy smoke tests

# $ensure = present
$ensure = purged


aws_vpc { 'test':
  region => 'us-west-2',
  cidr => '10.0.0.0/16',
  dhcp_options => 'test',
  ensure => $ensure
}

aws_hosted_zone{ 'test2.com.':
  ensure => $ensure

}

aws_s3_bucket{ "bobtfish-puppet-awsapi-testbucket":
  region => 'us-west-2',
  ensure => $ensure,
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
     cidr => '10.0.1.0/24',
  }

  aws_subnet {'alt':
     vpc => 'test',
     cidr => '10.0.2.0/24',
     unique_az_in_vpc => true,
  }

  aws_rds_instance {"rdsdb":
    allocated_storage => 5,
    db_instance_class => 'db.t2.micro',
    master_username => 'test',
    master_user_password => 'password1234',
    subnets => ['main', 'alt'],
    security_groups => ['test:default'],
  }




  aws_iam_role {'test':
    service_principal => 'ec2.amazonaws.com',
    permissions => [{
      "Effect" => "Allow",
      "Action" => ["s3:PutObject"],
      "Resource" => "arn:aws:s3:::puppet_test_bucket/*"
    }]
  }

  $ubuntu14 = {
      'us-west-2' => 'ami-e7b8c0d7', # Oregon
      'us-west-1' => 'ami-a7fdfee2', # Norcal
      'us-east-1' => 'ami-864d84ee', # Yes, Virginia
  }
  $ami = $ubuntu14['us-west-2']

  aws_security_group {"test:default":
  }

  aws_ec2_instance {"node":
    image_id => $ami,
    instance_type => 't2.micro',
    subnet => 'main',
    iam_role => 'test',
    security_groups => 'test:default',
    key_name => 'puppet-test',
    user_data => "secret=blahblhburgertown",
    associate_public_ip_address => true,
  }


  aws_rrset {"SRV _test._tcp.test2.com.":
    ttl => 123,
    zone => 'test2.com.',
    value => [
      '1 10 80 %{public_ip}',
      '1 10 %{port} %{cname}'
    ],
    targets => [
      Aws_ec2_instance['node'],
      Aws_rds_instance['rdsdb'],
    ]
  }





}
