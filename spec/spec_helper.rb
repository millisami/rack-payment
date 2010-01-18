ENV['RACK_ENV'] ||= 'test'

require File.dirname(__FILE__) + '/../lib/rack/payment'
require File.dirname(__FILE__) + '/../lib/rack/payment/test'
%w( rubygems spec rack/test webrat fakeweb sinatra/base ).each {|lib| require lib }

Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each     {|support| require support }
Dir[File.dirname(__FILE__) + '/../examples/**/*.rb'].each {|example| require example }

Webrat.configure do |config|
  config.mode = :rack
end

FakeWeb.allow_net_connect = false # just incase ActiveMerchant tries connecting ...
