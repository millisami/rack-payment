# Be sure to restart your server when you modify this file

# Specifies gem version of Rails to use when vendor/rails is not present
RAILS_GEM_VERSION = '2.3.5' unless defined? RAILS_GEM_VERSION

# Bootstrap the Rails environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

class MyMiddleware
  def initialize app
    @app = app
  end
  def call env
    if env['PATH_INFO'] == '/foo'
      [ 200, {}, ["Hello from my middleware!"] ]
    else
      @app.call env
    end
  end
end

Rails::Initializer.run do |config|
  # config.gem 'rack-payment'
  require Rails.root.join('..', '..', 'lib', 'rack-payment')
  config.time_zone = 'UTC'

  config.after_initialize do
    config.middleware.use Rack::Payment
    config.middleware.use MyMiddleware
  end
end
