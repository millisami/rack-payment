require File.dirname(__FILE__) + '/../lib/rack/payment'
%w( rubygems spec rack/test webrat fakeweb sinatra/base ).each {|lib| require lib }

Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each {|support| require support }

Webrat.configure do |config|
  config.mode = :rack
end

FakeWeb.allow_net_connect = false # just incase ActiveMerchant tries connecting ...
