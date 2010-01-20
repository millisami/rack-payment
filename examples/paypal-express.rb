require 'rubygems'
require 'sinatra/base'
require 'haml'
require File.dirname(__FILE__) + '/../lib/rack/payment' unless defined?(Rack::Payment)

ActiveMerchant::Billing::Base.mode = :test

class SimpleAppWithPayPalExpress < Sinatra::Base

  # For our specs, we need access to this gateway instance
  class << self; attr_accessor :gateway; end

  class << self
    attr_accessor :rack_payment_instance # expose the rack_purchase object so our specs can get it
  end

  use Rack::Session::Cookie
  use Rack::Payment

  use_in_file_templates!

  helpers do
    include Rack::Payment::Methods
  end

  get '/' do
    self.class.rack_payment_instance = env['rack.payment'] # <--- should be availabe via helper
    self.class.gateway               = env['rack.payment'].gateway
    haml :index
  end

  post '/' do
    payment.amount      = params[:monies]
    payment.use_express = params[:button] == 'Checkout with Paypal'
    [ 402, {}, ['Payment Required'] ]
  end

end

__END__

@@ index

%style
  :sass
    input.paypal_checkout
      :background-image url("https://www.paypal.com/en_US/i/btn/btn_xpressCheckout.gif")
      :background-color transparent
      :color            transparent
      :border           none
      :height           42px
      :width            145px

%form{ :action => '/', :method => 'post' }
  %label
    How many monies would you like to spend?
    %input{ :type => 'text', :id => 'monies', :name => 'monies' }
  %input{ :type => 'submit', :name => 'button', :value => 'Checkout' }
  %input.paypal_checkout{ :type => 'submit', :name => 'button', :value => 'Checkout with Paypal' }

@@ layout

!!! XML
!!! Strict
%html
  %head
    %title Rack::Payment Sample
  %body
    %h1 Rack::Payment Sample
    #content= yield
