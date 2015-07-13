require 'grit'

module Dockly::Util::Git
  module_function

  def git_repo
    @git_repo ||= Grit::Repo.new('.')
  end

  def git_sha
    @git_sha ||= git_repo.git.show.lines.first.chomp.match(/^commit ([a-f0-9]+)$/)[1][0..6] rescue 'unknown'
  end
end
