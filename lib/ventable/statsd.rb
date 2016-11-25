require 'ventable/statsd/version'
require 'ventable/statsd/tracker'

module Ventable
  module Statsd
    # @!parse extend Ventable::Statsd::Tracker::InstanceMethods
    def tracker
      Ventable::Statsd::Tracker.instance
    end

    def self.tracker
      Ventable::Statsd::Tracker.instance
    end

    def self.configure
      yield(Ventable::Statsd::Tracker.instance)
    end

    class << self
      # @!macro [attach] generate_method
      #   @method $1_way
      #   Sends $1 to +Ventable::Statsd::Tracker.instance+
      def self.gen(method)
        define_method(method) do |*args|
          tracker.send(method, *args)
        end
      end

      gen :handle_event
      gen :event_to_metric
      gen :event_to_metric_proc=
      gen :enable!
      gen :disable!
      gen :statsd=

   end
  end
end
