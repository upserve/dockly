# This module contains logic to find matching content hash for a given commit.
module Dockly::History
  module_function

  ASCII_FILE_SEP = 28.chr
  ASCII_RECORD_SEP = 30.chr

  TAG_PREFIX = 'dockly-'

  def push_content_tag!
    fail 'An SSH agent must be running to push the tag' if ENV['SSH_AUTH_SOCK'].nil?
    refs = ["refs/tags/#{content_tag}"]
    repo.remotes.each do |remote|
      username = remote.url.split('@').first
      creds = Rugged::Credentials::SshKeyFromAgent.new(username: username)
      remote.push(refs, credentials: creds)
    end
  end

  def write_content_tag!
    repo.tags.create(content_tag, repo.head.target_id, true)
  end

  def duplicate_build?
    !duplicate_build_sha.nil?
  end

  def duplicate_build_sha
    return @duplicate_build_sha if @duplicate_build_sha
    sha = tags[content_tag]
    @duplicate_build_sha = sha unless sha == repo.head.target_id
  end

  def tags
    @tags ||= Hash.new do |hash, key|
      tag = repo.tags[key]
      hash[key] = tag.target_id if tag
    end
  end

  def content_tag
    @content_tag ||= TAG_PREFIX + content_hash_for(ls_files)
  end

  def ls_files
    repo.head.target.tree.walk(:preorder)
      .map { |root, elem| [root, elem[:name]].compact.join }
      .select(&File.method(:file?))
  end

  def content_hash_for(paths)
    paths.sort.each_with_object(Digest::SHA384.new) do |path, hash|
      next unless File.exist?(path)
      mode = File::Stat.new(path).mode
      data = File.read(path)
      str = [path, mode, data].join(ASCII_RECORD_SEP.chr) + ASCII_FILE_SEP.chr
      hash.update(str)
    end.hexdigest
  end

  def repo
    @repo ||= Rugged::Repository.discover('.')
  end
end
