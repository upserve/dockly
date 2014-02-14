class Dockly::Docker::Registry
  include Dockly::Util::DSL
  include Dockly::Util::Logger::Mixin

  logger_prefix '[dockly docker registry]'

  dsl_attribute :name, :server_address, :email, :username, :password

  default_value :server_address, 'https://index.docker.io/v1/'

  def authenticate!
    ensure_present! :name, :server_address, :email, :username

    @password ||= ENV['DOCKER_REGISTRY_PASSWORD']

    debug "Attempting to authenticate at #{server_address}"
    ::Docker.authenticate!(
      'username' => username,
      'password' => password,
      'serveraddress' => server_address,
      'email' => email
    )
    info "Successfully authenticated at #{server_address} with username #{username}"
  rescue ::Docker::Error::AuthenticationError
    raise "Could not authenticate at #{server_address} with username #{username}"
  end
end
