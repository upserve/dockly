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
    prefix = prefix.dup
    unless prefix[-1] == '/'; prefix << '/'; end

    cmd = ['git','archive',"--prefix=#{prefix}",'--output=/dev/stdout',oid]
    Open3.popen3(*cmd) do |stdin, stdout, stderr, wait_thr|
      stdin.close

      output.write(stdout.read)
      process_status = wait_thr.value
      exit_status = process_status.exitstatus

      raise "#{cmd.join(' ')} exitted non-zero: #{exit_status}" unless exit_status.zero?
    end
  end
end
