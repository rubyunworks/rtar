module ProUtils
  module NilClass

    # Nil#status makes it possible to pass messages through
    # a "failure" chain.

    def status( *status )
      if status.empty?
        return @status
      else
        @status = status
        self
      end
    end

    # Check status.

    def status?
      return unless @status
      return false if @status.empty?
      return true
    end

  end
end

class NilClass #:nodoc:
  include ProUtils::NiClass
end

