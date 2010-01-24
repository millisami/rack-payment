require 'rubygems'
require 'sinatra/base'
require 'haml'
require File.dirname(__FILE__) + '/../lib/rack/payment' unless defined?(Rack::Payment)

ActiveMerchant::Billing::Base.mode = :test

# Has its own page with CC / Billing info
class SimpleAppWithOwnLayout < Sinatra::Base

  # For our specs, we need access to this gateway instance
  class << self; attr_accessor :gateway; end

  use Rack::Session::Cookie
  use Rack::Payment, :on_success => '/success'

  use_in_file_templates!

  helpers do
    include Rack::Payment::Methods
  end

  get '/' do
    self.class.gateway = env['rack.payment'].gateway
    haml :index
  end

  get '/styles.css' do
    content_type 'text/css'
    sass :styles
  end

  get '/success' do
    haml :success
  end

  post '/' do
    payment.amount = params[:monies]
    payment.credit_card.update     params[:credit_card]
    payment.billing_address.update params[:address]

    [ 402, {}, ['Payment Required'] ]
  end
end

__END__

@@ success

Order successful.

%p== payment.amount: #{ payment.amount }
%p== payment.amount_paid: #{ payment.amount_paid.inspect }

@@ index

%h1 Custom Page

= payment.form

@@ layout

!!! XML
!!! Strict
%html
  %head
    %title Rack::Payment Sample
    %link{ :rel => 'stylesheet', :type => 'text/css', :href => '/styles.css' }
  %body
    %h1 Rack::Payment Sample
    #content= yield
    
@@ styles

body
  :background-color #666
  :color            white

  form
    input
      :display block
