$LOAD_PATH.unshift File.dirname(__FILE__)

gem_bundler = File.dirname(__FILE__) + '/../vendor/gems/environment'
require gem_bundler if File.file?(gem_bundler)

%w( active_merchant rack bigdecimal forwardable ostruct erb ).each {|lib| require lib }

require 'rack-payment/callable_hash'
require 'rack-payment/payment'
require 'rack-payment/request'
require 'rack-payment/response'
require 'rack-payment/credit_card'
require 'rack-payment/billing_address'
require 'rack-payment/helper'
require 'rack-payment/methods'
