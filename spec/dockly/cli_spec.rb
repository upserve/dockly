require 'spec_helper'

describe "Aerosol CLI" do
  describe "running the most basic command" do
    let(:command) { "bundle exec ./bin/dockly" }
    it "should exit with 0" do
      expect(system(command)).to be_true
    end
  end
end
