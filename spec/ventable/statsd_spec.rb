require 'spec_helper'

module MyModule
  class UserRegisteredEvent
    include Ventable::Event
  end

  class FraudDetectedEvent
    include Ventable::Event
    class << self
      def statsd_config
        {
          method:  :gauge,
          value:   0.1,
          name:    'frauds_detected_this_hour',
          options: { sample_rate: 0.1 }
        }
      end
    end
  end
end

MyModule::UserRegisteredEvent.notifies Ventable::Statsd
MyModule::FraudDetectedEvent.notifies Ventable::Statsd

describe Ventable::Statsd do
  it 'has a version number' do
    expect(Ventable::Statsd::VERSION).not_to be nil
  end

  let(:fake_statsd) { FakeStatsd.new }
  before { Ventable::Statsd.configure { |config| config.statsd = fake_statsd } }

  context 'user_registered_event_count' do
    it 'should increment counter on statsd' do
      expect(fake_statsd).to receive(:increment).with('user_registered_count', 1, {})
      MyModule::UserRegisteredEvent.new.fire!
    end

    context 'when event_to_metric_proc is provided' do
      before do
        Ventable::Statsd.configure do |config|
          config.event_to_metric_proc = ->(event) do
            {
              method:  :set,
              value:   10,
              name:    Ventable::Statsd.event_to_metric(event) + '_set',
              options: { something_important: false }
            }
          end
        end
      end
      it 'should increment counter on statsd' do
        expect(fake_statsd).to receive(:set).with(
          'user_registered_set', 10, { something_important: false })
        MyModule::UserRegisteredEvent.new.fire!
      end
    end
  end

  context 'frauds_detected_this_hour' do
    it 'should update the gauge on statsd' do
      expect(fake_statsd).to receive(:gauge).with('frauds_detected_this_hour', 0.1, { sample_rate: 0.1 })
      MyModule::FraudDetectedEvent.new.fire!
    end
  end

  context 'when disabled' do
    before { Ventable::Statsd.disable! }
    it 'should not call statsd at all' do
      expect(fake_statsd).not_to receive(:gauge).with('frauds_detected_this_hour', 0.1, { sample_rate: 0.1 })
      MyModule::FraudDetectedEvent.new.fire!
    end
  end

  context 'when re-enabled' do
    before { Ventable::Statsd.disable!; Ventable::Statsd.enable! }
    it 'should not call statsd at all' do
      expect(fake_statsd).to receive(:gauge).with('frauds_detected_this_hour', 0.1, { sample_rate: 0.1 })
      MyModule::FraudDetectedEvent.new.fire!
    end
  end

  context 'include module' do
    class Moo
      include Ventable::Statsd
      def boo
        tracker.increment('moo_module_count', 1)
      end
    end

    it 'should increment the statistic' do
      expect(fake_statsd).to receive(:increment).with('moo_module_count', 1)
      Moo.new.boo
    end
  end

  context 'when statds is not set' do
    before { Ventable::Statsd.configure { |config| config.statsd = nil } }
    it 'should increment counter on statsd' do
      expect { MyModule::UserRegisteredEvent.new.fire! }.to raise_error(ArgumentError)
    end
  end
end
