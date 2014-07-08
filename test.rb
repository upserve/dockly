require 'pry'
require 'dockly'

rd, wr = IO.pipe(Encoding::ASCII_8BIT)

if fork
  begin
    wr.close

    base = File.open('swipely.tar', 'rb')
    output = File.open('output.tar', 'wb')

    td = Dockly::TarDiff.new(base, rd, output)
    td.process

    puts "Guess I'm done processing!!!"
    puts "Here's what's left: #{rd.read}"
  ensure
    rd.close
  end
else
  begin
    rd.close

    c = Docker::Container.create('Image' => 'swipely', 'Cmd' => 'true')
    c.start
    c.export do |chunk|
      wr.write(chunk)
    end
  ensure
    wr.close
  end
end

