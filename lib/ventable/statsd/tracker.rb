require 'singleton'
require 'ventable'
require 'active_support/inflections'

module Ventable
  module Statsd
    PROXIED_METHODS       = %i(increment gauge set measure)

    DEFAULT_CONFIGURATION = ->(event) { { method: :increment,
                                          value:  1,
                                          name:   event_to_metric(event) + '.count' } }

    # Main interface class which delegates some methods to the instance of
    # statsd in order to increment, or gauge/set various metrics.
    #
    # @attr [Statsd] statsd any statsd interface class that responds to methods listed in +PROXIED_METHODS+
    # @attr_reader [Bool] enabled set to false to bypass delegation
    # @attr_writer [Proc] event_to_metric_proc optional proc returning event configuration hash
    class Tracker
      include Singleton

      attr_writer :statsd, :enabled, :event_to_metric_proc

      private

      def initialize
        super
        @statsd               = nil
        @enabled              = true
        @event_to_metric_proc = nil
      end

      public

      PROXIED_METHODS.each do |method|
        define_method(method) do |metric, amount, *args|
          @statsd.send(method, metric, amount, *args)
        end
      end

      def enable!
        self.enabled = true
      end

      def disable!
        self.enabled = false
      end

      # A wrapper around the actual +Statsd+, which checks whether
      # the gem is enabled or disabled before calling +Statsd+.
      #
      # @param [Symbol] operation method name to send to the actual +Statsd+
      #
      # @example Increment a counter
      #   enable!
      #   statsd(:increment, 'my_event_count', 1)
      #
      # @return nil if disabled, or whatever +Statsd+ returns otherwise.
      def statsd(operation, *args, **opts, &block)
        if @enabled
          raise ArgumentError, 'statsd is not configured, please set it before recording events' unless @statsd
          self.send(operation, *args, **opts, &block)
        end
      end

      def handle_event(event)
        ec      = event_config(event)
        options = ec[:options] || {}
        statsd(ec[:method], *[ec[:name], ec[:value]], **options)
      end

      private

      def event_config(event)
        # defaults:
        config = DEFAULT_CONFIGURATION[event]

        if @event_to_metric_proc
          proc_config = @event_to_metric_proc.call(event) # expect a config Hash
          raise TypeError, "#event_to_metric_proc must return a hash, \neg. { method: :gauge, value: 0.1, name: 'frauds_detected_this_hour' }, \nbut I got #{proc_config.class.name}" unless proc_config.is_a?(Hash)
          config.merge!(proc_config) if proc_config
        end

        if event.class.respond_to?(:statsd_config)
          config.merge!(event.class.statsd_config(event))
        end

        config
      end

      def event_to_metric(event)
        event.
          class.
          name.
          gsub(/.*::/, '').
          underscore.
          gsub(/_?event/, '').
          gsub('_', '.')
      end
    end
  end
end
