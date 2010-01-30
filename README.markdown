Rack::Payment
=============

*View the documentation at: [http://yardoc.org/docs/frames/devfu-rack-payment](http://yardoc.org/docs/frames/devfu-rack-payment)*

{Rack::Payment} is a [Rack][] middleware for requiring single payments 
from your Ruby web applications.

We've purposefully called this Rack Payment, as opposed to Rack Payment**s**, 
because this middleware has no concept of multiple / recurring payments.

This simply makes it easy to collect individual payments, eg:

 * User adds some items to a shopping card
 * User clicks 'Checkout'
 * User fills out their billing information
 * User gets billed!

Ok, so what is this *really*?
-----------------------------

Really, this is just a Rack API / wrapper for [ActiveMerchant][].

With this, you can add 1 line of code to your web application and you'll get:

 * A page that lets a user fill out their billing information
 * A confirmation page, if the user's payment goes through 
 * Error messages, if the user's payment doesn't go through

Of course, it's very easy to override these pages yourself!

Install
-------

    $ sudo gem install rack-payment

Usage
-----

### Configuring the middleware

    require 'rack/payment'

    use Rack::Payment, :gateway   => 'paypal', 
                       :login     => 'bob', 
                       :password  => 'secret', 
                       :signature => '123abc', 
                       :test_mode => true

In a real application, you'll probably want {Rack::Payment} to be configured differently 
for your test/development/production environments.

By default, we look for a YAML configuration file in a few places, eg. `./config/rack-payment.yml`. 
If `RACK_ENV` or `RAILS_ENV` are set, we will load up that section of your YAML file.  You can view a 
sample YAML configuration file at: [http://github.com/devfu/rack-payment/blob/master/config/rack-payment.sample.yml][yml]

To access the main "API" of {Rack::Payment} you'll want to include a module in your code somewhere.  In Rails, you 
will probably want to include this in your ApplicationController (and maybe also your ApplicationHelper).  In Sinatra 
you will probably want to include this in your `helpers do ... end` block.

    class ApplicationController < ActionController::Base
      include Rack::Payment::Methods
    end

### Rails

In a Rails application, you'll probably want to create a `config/rack-payment.yml` file and put this into 
your `config/environment.rb`:

    Rails::Initializer.run do |config|
      config.gem 'rack-payment'

      # after_initialize so the rack-payment gem will be loaded 
      config.after_initialize do
        config.middleware.use Rack::Payment
      end
    end

### Requiring Payment

In your application, when you want a user to make a payment, you let {Rack::Payment} know how much 
you want to charge the user and then you return a [402 Payment Required][code] response code.

    class ProductsController < ApplicationController

      def purchase
        payment.amount = 19.95  # this might come from your product model or something like that
        head :payment_required  # this returns a 402 status code
      end

    end

That's it!  Your user will be redirected to a page where they can fill out their credit card & billing address!

The `payment` object that is made available by {Rack::Payment::Methods} is an instance of {Rack::Payment::Helper} and 
it is your primary "API" for interacting with {Rack::Payment}.

### Order Confirmation

By default, the user will be redirected to a simple page after the purchase goes through that merely says:

    Order successful.  You should have been charged 19.95

To override the confirmation page, you should override the `on_success` path:

    # on_success can *also* be configured via the YAML configuration file, if you prefer
    config.middleware.use Rack:Payment, :on_success => '/products/confirmation'

The page that is rendered `on_success` will have a few things available to it:

  * The payment amount that was requested (`payment.amount`)
  * The payment amount that was actually paid, which actually comes back from the server but should always be the same as the amount paid (`payment.amount_paid`)
  * A response object that contains the raw responses from the payment gateway (`payment.response`)

A simple custom page could be implemented like:

    class ProductsController < ApplicationController

      def confirmation
        render :text => "Thanks for your payment of #{ payment.amount_paid }!"
      end

    end

### Overriding the credit card / billing address page

Documentation coming soon ...

[rack]:           http://rack.rubyforge.org
[activemerchant]: http://www.activemerchant.org
[yml]:            http://github.com/devfu/rack-payment/blob/master/config/rack-payment.sample.yml
[code]:           http://en.wikipedia.org/wiki/HTTP_response_codes#4xx_Client_Error
