module Dockly::BuildCache
end

require 'dockly/build_cache/base'
require 'dockly/build_cache/docker'

module Dockly::BuildCache
  class << self
    attr_writer :model

    def model
      @mode ||= Dockly::BuildCache::Docker
    end
  end
end
