require 'spec_helper'

describe Dockly::AWS do
  subject { Dockly::AWS }

  describe '#reset_cache!' do
    before do
      subject.instance_variable_set(:@s3, double)
    end

    it 'sets @s3 to nil' do
      expect { subject.reset_cache! }
          .to change { subject.instance_variable_get(:@s3) }
          .to(nil)
    end
  end
end
