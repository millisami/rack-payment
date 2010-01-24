require 'rubygems'
require 'sinatra/base'
require 'haml'
require File.dirname(__FILE__) + '/../lib/rack/payment' unless defined?(Rack::Payment)

ActiveMerchant::Billing::Base.mode = :test

# Has its own page with CC / Billing info
class SimpleAppWithOwnLayout < Sinatra::Base

  use Rack::Session::Cookie
  use Rack::Payment, :on_success => '/success'

  use_in_file_templates!

  helpers do
    include Rack::Payment::Methods
  end

  get '/' do
    payment.amount = params[:amount]
    haml :index
  end

  post '/' do
    payment.amount = params[:amount]
    payment.credit_card.update     params[:credit_card]
    payment.billing_address.update params[:billing_address]

    [ 402, {}, ['Payment Required'] ] # will re-render the GET if invalid (?)
  end

  get '/styles.css' do
    content_type 'text/css'
    sass :styles
  end

  get '/success' do
    haml :success
  end
end

__END__

@@ success

Order successful.

%p== payment.amount: #{ payment.amount }
%p== payment.amount_paid: #{ payment.amount_paid.inspect }

@@ index

%h1 Custom Page

%p== payment.amount: #{ payment.amount }
%p== payment.amount_paid: #{ payment.amount_paid.inspect }

%h2 Here be my form!

= payment.form

%h2 And this is after the form

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
