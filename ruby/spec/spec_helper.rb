require "simplecov"
SimpleCov.start { minimum_coverage 80; add_filter "/spec/" }
require "webmock/rspec"
require "misar_mail"

WebMock.disable_net_connect!
