module Dockly::Util::Git
  module_function

  def git_repo
    @git_repo ||= Rugged::Repository.discover(File.expand_path('.'))
  end

  # This is needed to do git archives since that is not built in to rugged.
  def legacy_git_repo
    @legacy_git_repo ||= Grit::Repo.new('.')
  end

  def git_ls_files
    return enum_for(:git_ls_files) unless block_given?
    git_repo.head.target.tree.walk(:preorder).each do |root, elem|
      path = [root, elem[:name]].compact.join
      type = File.file?(path) ? :file : :dir
      mode = elem[:filemode]
      yield type: type, path: path, mode: mode
    end
  end

  def git_sha
    @git_sha ||= git_repo.head.target_id[0..6]
  end
end
