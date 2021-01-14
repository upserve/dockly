class Dockly::Docker::ECR
  include Dockly::Util::DSL
  include Dockly::Util::Logger::Mixin

  logger_prefix '[dockly docker ecr]'

  dsl_attribute :name, :server_address, :password, :username

  def authenticate!
    @username ||= login_from_aws[0]
    @password ||= login_from_aws[1]

    ensure_present! :password, :server_address, :username

    debug "Attempting to authenticate at #{server_address}"

    ::Docker.authenticate!(self.to_h)

    info "Successfully authenticated at #{server_address}"
  rescue ::Docker::Error::AuthenticationError
    raise "Could not authenticate at #{server_address}"
  end

  def authentication_required?
    true
  end

  def default_server_address?
    false
  end

  def login_from_aws
    @login_from_aws ||=
      Base64
        .decode64(auth_data.authorization_token)
        .split(':')
  end

  def auth_data
    @auth_data ||=
      client
        .get_authorization_token
        .authorization_data
        .first
  end

  def client
    @client ||= Aws::ECR::Client.new(region: 'us-east-1')
  end

  def to_h
    ensure_present! :username, :password, :server_address

    {
      'serveraddress' => "https://#{server_address}",
      'username' => username,
      'password' => password
    }
  end
end
