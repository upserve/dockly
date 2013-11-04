require 'fog/aws'

# This module holds the connections for all AWS services used by the gem.
module SwipelyBuilder::AWS
  extend self

  def service(name, klass)
    define_method name do
      if val = instance_variable_get(:"@#{name}")
        val
      else
        instance = klass.new(creds)
        instance_variable_set(:"@#{name}", instance)
      end
    end
    services << name
  end

  def services
    @services ||= []
  end

  def env_attr(*names)
    names.each do |name|
      define_method name do
        instance_variable_get(:"@#{name}") || ENV[name.to_s.upcase]
      end

      define_method :"#{name}=" do |val|
        reset_cache!
        instance_variable_set(:"@#{name}", val)
      end

      env_attrs << name
    end
  end

  def env_attrs
    @env_attrs ||= []
  end

  def creds
    attrs = Hash[env_attrs.map { |attr| [attr, public_send(attr)] }].reject { |k, v| v.nil? }
    if attrs.empty?
      if ENV['FOG_CREDENTIAL']
        attrs = {} # let Fog use the env var
      else
        attrs = { :use_iam_profile => true }
      end
    end
    attrs
  end

  def reset_cache!
    services.each { |service| instance_variable_set(:"@#{service}", nil) }
  end

  service :s3, Fog::Storage::AWS
  env_attr :aws_access_key_id, :aws_secret_access_key
end
