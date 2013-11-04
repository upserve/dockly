require 'foreman/cli'

class Foreman::CLI
  private
  # Because are you serious foreman????
  def error(message)
    raise "ERROR: #{message}"
  end
end
