
[![Build Status](https://travis-ci.org/kigster/ventable-statsd.svg?branch=master)](https://travis-ci.org/kigster/ventable-statsd)
[![Gem Version](https://badge.fury.io/rb/ventable-statsd.svg)](https://badge.fury.io/rb/ventable-statsd)
[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/kigster/simple-feed/master/LICENSE.txt)
[![Code Climate](https://codeclimate.com/repos/5838e1481bb659572d005ee8/badges/056591d5b5c1875fceac/gpa.svg)](https://codeclimate.com/repos/5838e1481bb659572d005ee8/feed)
[![Test Coverage](https://codeclimate.com/repos/5838e1481bb659572d005ee8/badges/056591d5b5c1875fceac/coverage.svg)](https://codeclimate.com/repos/5838e1481bb659572d005ee8/coverage)
[![Issue Count](https://codeclimate.com/repos/5838e1481bb659572d005ee8/badges/056591d5b5c1875fceac/issue_count.svg)](https://codeclimate.com/repos/5838e1481bb659572d005ee8/feed)

# Ventable::Statsd – Easily Track Application Events with Statsd

This library is a small extension to the
[Ventable](https://github.com/kigster/ventable) eventing library. It
provides out of the box support for tracking Ventable events using
Statsd. 

Why? Because by utilizing Ventable's powerful abstraction you can map
the most important events in the system as classes, and then subscribe
them all globally to the `Statsd` collector.

This gem does not depend on any particular implementation of `statsd`
client library, and it expects that you create a `statsd` client and
pass it via the `.configure` to the `Ventable::Statsd`. 

The client should typically respond to the methods such as `increment`,
`gauge`, `set`, `measure` and expect the metric name and value to be
it's parameters. The methods were modelled based on the
[`statsd-instrument`](https://github.com/Shopify/statsd-instrument) ruby
gem, but it should be compatible with many others.

## Usage

The gem works as follows:

1. You configure the backend
2. You register your ventable events to notify `Ventable::Statsd`
3. You either follow the default naming strategy, or provide your own.
   See [Naming Events](#naming-events) further down.

### Configuration

Before we can track our events, let's configure our statsd:

```ruby
require 'statsd-instrument'
require 'ventable/statsd'

# see https://github.com/Shopify/statsd-instrument for more info
StatsD.backend = StatsD::Instrument::Backends::UDPBackend.new("172.16.0.1:8125", :statsd)

Ventable::Statsd.configure do |config|
  config.statsd = StatsD
  config.enabled = true
end
```

### Registration of the Events

Now we must connect the event dispatch mechanism with the
`Ventable::Statsd` module:

```ruby
class ApplicationOpenedEvent
  include Ventable::Event
end

# Subscribe the event to track event dispatch
ApplicationOpenedEvent.notifies Ventable::Statsd

# Now fire the event, and it should send a packet to statsd!
ApplicationOpenedEvent.new.fire!
#=> calls StatsD.increment('application_opened_count', 1)
```

Or you can register `Ventable::Statsd` in a super class of all of your
application events, so that you don't have to repeat this code:

```ruby
class AbstractEvent
  def self.inherited(klass)
    klass.instance_eval do
      include Ventable::Event
    end
    klass.notifies Ventable::Statsd
  end
end

class ApplicationOpenedEvent < AbstractEvent; end
```

<a name='naming-events'></a>

### Naming Metrics from Events
  
The biggest customization lies within the way you might like to map
various event occurring to a specific metric name in the Graphite
database.

As you might now, when metric name is separated by a dot '.', Graphite
create sub-folders and group sub-metrics together. For example
`order.completed.count` and `order.cancelled.count` would be grouped
together under `order.*` in Graphite.

This is why the default naming scheme uses your event class name,
converts it to a lower-case underscored version, and replaces all
underscores with a dot (while also removing redundant `_event` if
there). This way, an event named, say `UserRegistrationCompletedEvent`
would be converted to a metric name `user.registration.completed.count`.
Note how the default metric type is `count`, which would be registered
by calling `increment(name, 1)` on `Statsd`.

#### Customizing Event-to-Metric Naming 

But what if you wanted to customize how metrics are called? 

What if you want to keep track of some events as a gauge and not the counter?

In these and other cases, there are two ways to customize the event
names. But before we jump in to see how these are configured, let's
discuss what these procs are expected to return.

##### Event Naming Hash

The *return* of naming customization method/proc is a complete or any
portion of the following hash — and here are a couple of examples that
hopefully explain how this hash is used by the library:

```ruby
 # Method to call on statsd; and its value        Metric to pass to Statsd
 { method: :increment, value: 1,           name: 'graphite.metric.name' }
 { method: :gauge,     value: event.total, name: 'graphite.aggregate.gauge' }
```


##### Globally via a Proc
 
You can configure a proc at the top level that receives an event as a
parameter, and returns an _event naming hash_ (see above) for a given
event. This can be useful if you can write a single proc that covers all
of your cases in one place, but is distinct from the default naming.

The argument to the proc or method is the event instance. 

Below we provide the metric naming algorithm in the configuration clause
for the gem:

```ruby
Ventable::Stats.configure do |c|
  # this would return a name 'my_event.count' for MyEvent
  c.event_to_metric_proc = ->(event) { { method: :increment,
                                          value:  1,
                                           name:  event.class.name.underscore + '.count' } }
end
```

##### Via a class method `statsd_config`

You can also configure each event with a class method `statsd_config`
that receives an event instance as an argument, and must return the
_event naming hash_ to customize the naming and statsd methods.

While in the previous example above the proc was applied to all events,
the following would only apply to the concrete event classes below:

```ruby
class OrderShippedEvent
  attr_accessor :carrier
  class << self
    def statsd_config
        ->(event) { { method: :increment,
                       value:  1,
                        name:  "order.shipped.#{event.carrier.code}.count" } }
    end
  end                      
end

class OrderReturnStartedEvent
  class << self
    def statsd_config
        ->(*) { { name:  'order.returns.count' } }
    end
  end                      
end
```

The above examples demonstrate the flexibility of the naming: 

1. In the first example, `OrderShippedEvent` is supposed have `carrier`
   accessor, which in turn has a `code` — presumably returning a short
   string, one of `%w(fedex ups dhl)` etc. By using this custom naming
   scheme we are able to group in Graphite our shipping completions by
   carrier without having to create a new event class for each carrier
   type.
2. In the second example we do not care about the event instance, but
   provide the gem with an alternative name for this event. Note also
   that we are not including `:method` or `:value`, which would then be
   used from the defaults.


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ventable-statsd'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ventable-statsd

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/kigster/ventable-statsd.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

