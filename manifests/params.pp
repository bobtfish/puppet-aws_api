# == Class aws_api::params
#
# This class is meant to be called from aws_api
# It sets variables according to platform
#
class aws_api::params {
  case $::osfamily {
    'Debian': {
      $package_name = 'aws_api'
      $service_name = 'aws_api'
    }
    'RedHat', 'Amazon': {
      $package_name = 'aws_api'
      $service_name = 'aws_api'
    }
    default: {
      fail("${::operatingsystem} not supported")
    }
  }
}
