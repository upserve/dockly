module Dockly::Util::Git
  module_function

  def repo
    @repo ||= MiniGit.new('.')
  end

  def sha
    return @sha if @sha
    @sha = repo.capturing.rev_parse('HEAD').chomp
  rescue
    @sha = 'unknown'
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
