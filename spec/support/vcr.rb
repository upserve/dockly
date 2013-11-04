require 'webmock'
require 'vcr'

WebMock.disable_net_connect!

VCR.configure do |c|
  c.allow_http_connections_when_no_cassette = true
  c.hook_into :webmock
  c.cassette_library_dir = File.join(File.dirname(File.dirname(__FILE__)), 'vcr')
  c.configure_rspec_metadata!
end
