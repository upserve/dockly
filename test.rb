require 'pry'
require 'dockly'

base = File.open('swipely.tar', 'rb')
output = File.open('output.tar', 'wb')

td = Dockly::TarDiff.new(base, output)

c = Docker::Container.create('Image' => 'swipely', 'Cmd' => 'true')
c.start
c.export do |chunk|
  td.set_chunk(chunk)
  while td.process; end
end
