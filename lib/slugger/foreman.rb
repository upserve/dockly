class Slugger::Foreman
  include DSL::DSL
  include DSL::Logger::Mixin

  logger_prefix '[slugger foreman]'
  dsl_attribute :name, :env, :procfile, :type, :user, :root_dir, :init_dir,
                :log_dir, :build_dir, :prefix

  default_value :build_dir, 'build/foreman'
  default_value :env, ""
  default_value :procfile, './Procfile'
  default_value :type, 'upstart'
  default_value :user, 'nobody'
  default_value :root_dir, "/tmp"
  default_value :init_dir, "/etc/init"
  default_value :log_dir, '/var/log'

  def create!
    ensure_present! :name, :init_dir, :build_dir, :procfile, :type, :user

    info "cleaning build dir"
    FileUtils.rm_rf(build_dir)
    FileUtils.mkdir_p(build_dir)
    cli = ::Foreman::CLI.new
    cli.options = {
      :root => root_dir,
      :env => env,
      :procfile => procfile,
      :app => name,
      :log => log_dir,
      :prefix => prefix,
      :user => user,
    }
    info "exporting"
    cli.export(type, build_dir)
  end
end
