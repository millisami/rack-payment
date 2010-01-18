require 'rubygems'
require 'sinatra/base'
require 'haml'
require File.dirname(__FILE__) + '/../lib/rack/payment' unless defined?(Rack::Payment)

ActiveMerchant::Billing::Base.mode = :test

# .gateway.rb should be set in your root path and it should 
# specify an ActiveMerchant::Billing::Gateway with the 
# constant GATEWAY
require File.dirname(__FILE__) + '/../.gateway' unless ENV['RACK_ENV'] == 'test'

# Overrides on_success with its own page
class SimpleAppWithOnSuccessOverridden < Sinatra::Base

  # For our specs, we need access to this gateway instance
  class << self; attr_accessor :gateway; end
  @gateway = ENV['RACK_ENV'] == 'test' ? ActiveMerchant::Billing::BogusGateway.new : Kernel.const_get(:GATEWAY)

  use Rack::Session::Cookie
  use Rack::Payment, gateway, :on_success => '/custom_success_page'

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

  get '/custom_success_page' do
    haml :on_success
  end
end

__END__

@@ on_success

%h2  w00t!  Success!

%p== You should have been charged #{ payment.amount } (#{ payment.amount_in_cents })

%p Raw capture response:
%pre~ payment.capture_response.inspect

%p Raw authoriziation request:
%pre~ payment.authorize_response.inspect

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
    %title Rack::Payment Sample (on_success override)
  %body
    %h1 Rack::Payment Sample (on_success override)
    #content= yield
