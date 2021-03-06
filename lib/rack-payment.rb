$LOAD_PATH.unshift File.dirname(__FILE__)

# Move this out of here???  Used for continuous integration
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
require 'rack-payment/billable'
require 'rack-payment/encrypted_credit_card'

# Helpers for particular Billable ORMs require explicit requirements
# require 'rack-payment/billable/datamapper'
# require 'rack-payment/billable/activerecord'
