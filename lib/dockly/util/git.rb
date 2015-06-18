module Dockly::Util::Git
  module_function

  def git_repo
    @git_repo ||= Rugged::Repository.discover(File.expand_path('.'))
  end

  def git_archive_to_file(prefix, file)
    File.open(file, 'w') do |io|
      git_archive_to_file(prefix, io)
    end
  end

  def git_archive(prefix, io)
    git_ls_files.each_with_object(Gem::Package::TarWriter.new(io)) do |hash, writer|
      type, path, mode = hash.values_at(:type, :path, :mode)
      full_path = File.join(prefix, path)
      if type == :file
        writer.add_file(full_path, mode) { |writer_io| writer_io.write(File.read(path)) }
      else
        writer.mkdir(full_path, mode)
      end
    end.tap(&:close)
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
