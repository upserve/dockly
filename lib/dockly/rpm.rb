require 'fpm'

class Dockly::Rpm < Dockly::Deb
  logger_prefix '[dockly rpm]'
  dsl_attribute :os
  default_value :deb_build_dir, 'rpm'
  default_value :os, 'linux'

  def output_filename
    "#{package_name}_#{version}.#{release}_#{arch}.rpm"
  end

private
  def convert_package
    debug "converting to rpm"
    @deb_package = @dir_package.convert(FPM::Package::RPM)

    @deb_package.scripts[:before_install] = pre_install
    @deb_package.scripts[:after_install] = post_install
    @deb_package.scripts[:before_remove] = pre_uninstall
    @deb_package.scripts[:after_remove] = post_uninstall

    @deb_package.name = package_name
    @deb_package.version = version
    @deb_package.iteration = release
    @deb_package.architecture = arch
    @deb_package.vendor = vendor

    # rpm specific configs
    @deb_package.attributes[:rpm_rpmbuild_define] ||= []
    @deb_package.attributes[:rpm_defattrfile] = "-"
    @deb_package.attributes[:rpm_defattrdir] = "-"
    @deb_package.attributes[:rpm_user] = "root"
    @deb_package.attributes[:rpm_group] = "root"
    @deb_package.attributes[:rpm_os] = os
  end
end
