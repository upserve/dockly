require 'dsl'
require 'fog'
require 'pry'
require 'foreman/cli_fix'
require 'foreman/export/base_fix'

module SwipelyBuilder
end

require 'swipely_builder/aws'
require 'swipely_builder/foreman'
require 'swipely_builder/build_cache'
require 'swipely_builder/docker'
require 'swipely_builder/deb'
require 'swipely_builder/util'
