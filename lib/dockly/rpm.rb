require 'fpm'

class Dockly::Rpm < Dockly::Deb
  logger_prefix '[dockly rpm]'
  dsl_attribute :os
  default_value :deb_build_dir, 'rpm'
  default_value :os, 'linux'

  def output_filename
    "#{package_name}_#{version}.#{release}_#{arch}.rpm"
  end

  def startup_script
    scripts = []
    bb = Dockly::BashBuilder.new
    scripts << bb.normalize_for_dockly
    scripts << bb.get_and_install_rpm(s3_url, "/opt/dockly/#{File.basename(s3_url)}")

    scripts.join("\n")
  end

private
  def convert_package
    debug "converting to rpm"
    @deb_package = @dir_package.convert(FPM::Package::RPM)

    # rpm specific configs
    @deb_package.attributes[:rpm_rpmbuild_define] ||= []
    @deb_package.attributes[:rpm_defattrfile] = "-"
    @deb_package.attributes[:rpm_defattrdir] = "-"
    @deb_package.attributes[:rpm_user] = "root"
    @deb_package.attributes[:rpm_group] = "root"
    @deb_package.attributes[:rpm_os] = os
  end
end
