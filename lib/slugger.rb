require 'dsl'
require 'fog'
require 'pry'
require 'foreman/cli_fix'
require 'foreman/export/base_fix'

module Slugger
end

require 'slugger/aws'
require 'slugger/foreman'
require 'slugger/build_cache'
require 'slugger/docker'
require 'slugger/deb'
require 'slugger/util'
