require 'rubygems'
require 'sinatra/base'
require 'haml'
require File.dirname(__FILE__) + '/../lib/rack/payment' unless defined?(Rack::Payment)

ActiveMerchant::Billing::Base.mode = :test

# Has its own page with CC / Billing info
class SimpleAppWithOwnCreditCardPage < Sinatra::Base

  # For our specs, we need access to this gateway instance
  class << self; attr_accessor :gateway; end

  use Rack::Session::Cookie
  use Rack::Payment, YAML.load_file(File.dirname(__FILE__) + '/../.gateway.yml')[ ENV['RACK_ENV'] ]

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

  post '/' do
    payment.amount = params[:monies]
    payment.credit_card.update     params[:credit_card]
    payment.billing_address.update params[:address]

    [ 402, {}, ['Payment Required'] ]
  end
end

__END__

@@ index

%h1 Custom Page

- unless payment.errors.empty?
  %p= payment.errors.join(', ')

%form{ :action => '/', :method => 'post' }

  %label
    How many monies would you like to spend?
    %input{ :type => 'text', :id => 'monies', :name => 'monies', :value => payment.amount }

    - %w( first_name last_name number cvv expiration_month expiration_year type ).each do |field|
      - full_field = "credit_card[#{field}]"
      %label
        = field.gsub('_', ' ').capitalize
        %input{ :type => 'text', :name => full_field, :value => payment.credit_card[field] }

    - %w( name address1 city state country zip ).each do |field|
      - full_field = "address[#{ field }]"
      %label
        = field.gsub('_', ' ').capitalize
        %input{ :type => 'text', :name => full_field, :value => payment.billing_address[field] }
  
  %input{ :type => 'submit', :value => 'Purchase' }

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
