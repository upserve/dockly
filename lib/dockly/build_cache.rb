module Dockly::BuildCache
end

module Dockly::BuildCache
  autoload :Base, 'dockly/build_cache/base'
  autoload :Docker, 'dockly/build_cache/docker'
  autoload :Local, 'dockly/build_cache/local'

  class << self
    attr_writer :model

    def model
      @model ||= Dockly::BuildCache::Docker
    end
  end
end
