Rack::Payment
=============

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

Usage
-----

Coming soon!  Gotta make the specs pass first ...


[rack]:           http://rack.rubyforge.org
[activemerchant]: http://www.activemerchant.org
