class Dockly::Docker::Registry
  include Dockly::Util::DSL
  include Dockly::Util::Logger::Mixin

  DEFAULT_SERVER_ADDRESS = 'https://index.docker.io/v1/'

  logger_prefix '[dockly docker registry]'

  dsl_attribute :name, :server_address, :email, :username, :password,
                :authentication_required

  default_value :server_address, DEFAULT_SERVER_ADDRESS
  default_value :authentication_required, true

  alias_method :authentication_required?, :authentication_required

  def authenticate!
    return unless authentication_required?

    @password ||= ENV['DOCKER_REGISTRY_PASSWORD']
    ensure_present! :email, :password, :server_address, :username

    debug "Attempting to authenticate at #{server_address}"
    ::Docker.authenticate!(self.to_h)
    info "Successfully authenticated at #{server_address} with username #{username}"
  rescue ::Docker::Error::AuthenticationError
    raise "Could not authenticate at #{server_address} with username #{username}"
  end

  def default_server_address?
    server_address == DEFAULT_SERVER_ADDRESS
  end

  def to_h
    {
      'serveraddress' => server_address,
      'email' => email,
      'username' => username,
      'password' => password
    }
  end
end
