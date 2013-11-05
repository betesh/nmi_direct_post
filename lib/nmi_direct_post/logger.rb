module NmiDirectPost
  class << self
    def logger
      @logger ||= defined?(::Rails) ? Rails.logger : ::Logger.new(STDOUT)
    end
    def logger=(_)
      raise ArgumentError, "NmiDirectPost logger must respond to :info and :debug" unless logger_responds(_)
      @logger = _
    end
    private
      def logger_responds(logger)
        logger.respond_to?(:info) && logger.respond_to?(:debug)
      end
  end
end
