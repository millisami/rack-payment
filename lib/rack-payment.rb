$LOAD_PATH.unshift File.dirname(__FILE__)

%w( active_merchant rack bigdecimal forwardable ostruct erb ).each {|lib| require lib }

require 'rack-payment/payment'
require 'rack-payment/request'
require 'rack-payment/credit_card'
require 'rack-payment/billing_address'
require 'rack-payment/data'
require 'rack-payment/methods'
