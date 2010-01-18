require 'rubygems'
require 'sinatra/base'
require 'haml'
require File.dirname(__FILE__) + '/../lib/rack/payment' unless defined?(Rack::Payment)

ActiveMerchant::Billing::Base.mode = :test

# .gateway.rb should be set in your root path and it should 
# specify an ActiveMerchant::Billing::Gateway with the 
# constant GATEWAY
require File.dirname(__FILE__) + '/../.gateway' unless ENV['RACK_ENV'] == 'test'

class SimpleApp < Sinatra::Base

  # For our specs, we need access to this gateway instance
  class << self; attr_accessor :gateway; end
  @gateway = ENV['RACK_ENV'] == 'test' ? ActiveMerchant::Billing::BogusGateway.new : Kernel.const_get(:GATEWAY)

  use Rack::Session::Cookie
  use Rack::Payment, gateway

  use_in_file_templates!

  helpers do
    include Rack::Payment::Methods
  end

  get '/' do
    haml :index
  end

  post '/' do
    payment.amount = params[:monies]
    [ 402, {}, ['Payment Required'] ]
  end

end

__END__

@@ index

%form{ :action => '/', :method => 'post' }
  %label
    How many monies would you like to spend?
    %input{ :type => 'text', :id => 'monies', :name => 'monies' }
  %input{ :type => 'submit', :value => 'Checkout' }

@@ layout

!!! XML
!!! Strict
%html
  %head
    %title Rack::Payment Sample
  %body
    %h1 Rack::Payment Sample
    #content= yield
