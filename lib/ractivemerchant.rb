require 'active_merchant'

# Rack middleware for easily integrating {ActiveMerchant} purchases 
# into you application.
#
# This does NOT provide a shopping cart and it is not aware of your 
# website's products.  This merely gives you a relative URL that 
# your application can POST to which will, given the variables, 
# make a purchase using the {ActiveMerchant::Billing::Gateway} 
# that you provide.
#
# This also provides a relative URL that you can redirect to and 
# it will display a form with the appropriate fields to allow 
# a user to make a purchase.  This is a sample page and it's 
# assumed that most applications will actually override this 
# by providing you own page.  This page does work though!
#
# See specs for usage
#
class RActiveMerchant

  # Default options that are passed to RActiveMerchant instances when initialized.
  DEFAULT_OPTIONS = {
    :path_prefix        => '/ractivemerchant',
    :purchase_path      => '/purchase',
    :purchase_form_path => '/purchase',
    :on_success_path    => '/confirmation',
    :on_error_path      => '/error',
    :env_variable       => 'rack.ractivemerchant'
  }

  attr_accessor :app

  attr_accessor :gateway

  attr_accessor :env_variable

  attr_accessor :path_prefix

  # Writer methods for paths.  Getters are overriden.
  attr_writer :purchase_path, :purchase_form_path, :on_success_path, :on_error_path

  def purchase_path
    if @purchase_path == DEFAULT_OPTIONS[:purchase_path]
      File.join path_prefix, @purchase_path
    else
      @purchase_path
    end
  end

  def purchase_form_path
    if @purchase_form_path == DEFAULT_OPTIONS[:purchase_form_path]
      File.join path_prefix, @purchase_form_path
    else
      @purchase_form_path
    end
  end

  def on_success_path
    if @on_success_path == DEFAULT_OPTIONS[:on_success_path]
      File.join path_prefix, @on_success_path
    else
      @on_success_path
    end
  end

  def on_error_path
    if @on_error_path == DEFAULT_OPTIONS[:on_error_path]
      File.join path_prefix, @on_error_path
    else
      @on_error_path
    end
  end

  # @param [#call] Rack application
  # @param [#purchase] {ActiveMerchant::Billing::Gateway}
  def initialize rack_application, active_merchant_gateway, options = nil
    raise ArgumentError, 'You must pass a valid Rack application' unless rack_application.respond_to?(:call)
    raise ArgumentError, 'You must pass a valid Gateway'          unless active_merchant_gateway.respond_to?(:purchase)

    @app     = rack_application
    @gateway = active_merchant_gateway

    DEFAULT_OPTIONS.each {|name, value| send "#{name}=", value }
    options.each         {|name, value| send "#{name}=", value } if options
  end

  # @param [Hash] The Rack Request environment variables
  def call env
    # put this instance of RActiveMerchant in the env so it's accessible from the application
    env[env_variable] = self

    # Return the response from the Rack application
    @app.call(env)
  end

end
