require "spec_helper"

class DebugLogger
  def debug(_)
  end
end

class InfoLogger
  def info(_)
  end
end

module NmiDirectPost
  class << self
    def reset_logger
      @logger = nil
    end
  end
end

module RailsWithLogger
  class << self
    def logger
      @logger = Logger.new('/tmp/rails_logger')
    end
  end
end

module RailsWithoutLogger
end

describe NmiDirectPost do
  describe "logger" do
    before(:each) do
      NmiDirectPost.reset_logger
    end
    after(:all) do
      NmiDirectPost.reset_logger
    end

    it "should default to a STDOUT logger if Rails is not defined" do
      expect(NmiDirectPost.logger.instance_variable_get("@logdev").instance_variable_get("@dev")).to eq(STDOUT)
    end

    describe "Rails.logger is defined" do
      before(:each) do
        stub_const("::Rails", RailsWithLogger)
      end

      it "should default to the Rails logger if Rails.logger is defined" do
        expect(NmiDirectPost.logger.instance_variable_get("@logdev").instance_variable_get("@dev").inspect).to eq(File.new('/tmp/rails_logger').inspect)
      end

      after(:each) do
        `rm /tmp/rails_logger`
      end
    end

    describe "Rails is defined but Rails.logger is not" do
      before(:each) do
        stub_const("::Rails", RailsWithoutLogger)
      end

      it "should default to a STDOUT logger" do
        expect(NmiDirectPost.logger.instance_variable_get("@logdev").instance_variable_get("@dev")).to eq(STDOUT)
      end
    end

    it "should fail to be set to an object that doesn't respond to info" do
      expect { NmiDirectPost.logger = DebugLogger.new }.to raise_error(ArgumentError, "NmiDirectPost logger must respond to :info and :debug")
    end

    it "should fail to be set to an object that doesn't respond to debug" do
      expect { NmiDirectPost.logger = InfoLogger.new }.to raise_error(ArgumentError, "NmiDirectPost logger must respond to :info and :debug")
    end
  end
end
