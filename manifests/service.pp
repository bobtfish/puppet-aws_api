# == Class aws_api::service
#
# This class is meant to be called from aws_api
# It ensure the service is running
#
class aws_api::service {
  include aws_api::params

  service { $aws_api::params::service_name:
    ensure     => running,
    enable     => true,
    hasstatus  => true,
    hasrestart => true,
  }
}
