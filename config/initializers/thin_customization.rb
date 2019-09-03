require 'logger'

#monkey patch thin to add timestamps to logging
module Thin
  module Logging
    class SimpleFormatter < Logger::Formatter
      def call(severity, timestamp, progname, msg)
        "#{timestamp} #{String === msg ? msg : msg.inspect}\n"
      end
    end
  end
end

