require 'rubygems'
require 'sinatra/base'
require 'haml'
require File.dirname(__FILE__) + '/../lib/rack/payment' unless defined?(Rack::Payment)

ActiveMerchant::Billing::Base.mode = :test

# Simple example using defaults
class SimpleApp < Sinatra::Base

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
