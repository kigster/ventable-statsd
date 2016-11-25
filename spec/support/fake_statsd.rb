require 'ventable/statsd'


class FakeStatsd
  Ventable::Statsd::PROXIED_METHODS.each do |method|
    define_method(method) do |*|
    end
  end
end


