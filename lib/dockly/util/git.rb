module Dockly::Util::Git
  module_function

  def repo
    @repo ||= Rugged::Repository.discover('.')
  end

  def sha
    return @sha if @sha
    @sha = repo.head.target.oid[0..6]
  rescue
    @sha = 'unknown'
  end

  def ls_files(oid)
    target = repo.lookup(oid)
    target = target.target until target.type == :commit
    ary = []
    target.tree.walk(:postorder) do |root, entry|
      next unless entry[:type] == :blob
      name = File.join(root, entry[:name]).gsub(/\A\//, '')
      ary << entry.merge(name: name)
    end
    ary
  end

  def archive(oid, prefix, output)
    Gem::Package::TarWriter.new(output) do |tar|
      ls_files(oid).each do |blob|
        name, mode = blob.values_at(:name, :filemode)
        prefixed = File.join(prefix, name)
        tar.add_file(prefixed, mode) do |tar_out|
          tar_out.write(File.read(name))
        end
      end
    end
  end
end
