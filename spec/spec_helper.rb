ENV['RACK_ENV']  ||= 'test'
ENV["RAILS_ENV"] ||= 'test'

# Rails wnats to be loaded before anything else because it's selfish
require File.dirname(__FILE__) + '/../examples/rails-example/config/environment'
require File.dirname(__FILE__) + '/../examples/rails-example/db/migrate/20100129225010_create_products'
CreateProducts.migrate :up
RAILS_APP = ActionController::Dispatcher.new

require File.dirname(__FILE__) + '/../lib/rack/payment'
require File.dirname(__FILE__) + '/../lib/rack/payment/test'
%w( rubygems spec rack/test webrat fakeweb sinatra/base tempfile time ).each {|lib| require lib }

Dir[File.dirname(__FILE__) + '/support/**/*.rb'].each     {|support| require support }
Dir[File.dirname(__FILE__) + '/../examples/*.rb'].each {|example| require example }

# Log everything, just for kicks
FileUtils.rm_f(File.dirname(__FILE__) + '/rack-payment-specs.log')
Rack::Payment.logger = Logger.new(File.dirname(__FILE__) + '/rack-payment-specs.log')

Webrat.configure do |config|
  config.mode = :rack
end

FakeWeb.allow_net_connect = false # just incase ActiveMerchant tries connecting ...
