require 'rubygems'
require 'sinatra'
require 'haml'
require File.dirname(__FILE__) + '/../lib/rack/payment'

ActiveMerchant::Billing::Base.mode = :test

# .gateway.rb should be set in your root path and it should 
# specify an ActiveMerchant::Billing::Gateway with the 
# constant GATEWAY
require File.dirname(__FILE__) + '/../.gateway'

use Rack::Session::Cookie
use Rack::Payment, GATEWAY

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
