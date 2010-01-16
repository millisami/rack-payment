RActiveMerchant
===============

RActiveMerchant = Rack + ActiveMerchant

Ideas
-----

This isn't complete yet, so here are merely some ideas ...

All paths overridable!

GET /ractivemerchant/checkout

    A UI for filling out credit card payment, etc.
    You need to pass it the amount you want to buy.
    You can pass it text/info to display, maybe?
    KISS because you can override this view!

POST /ractivemerchant/purchase

    This actually does the purchase.

    If it works, it redirects to /ractivemerchant/complete.

    If it doesn't, it redirects BACK (eg. back to /checkout)
    providing details on why it didn't work.

env['ractivemerchant'] will be used for passing data within single requests.

For instance, after a POST to /purchase, you'll be able to get the actual 
ActiveMerchant response object(s) via env['ractivemerchant'], if you want them.

Example:

    gateway = ActiveMerchant::Billing::Base.gateway('paypal').new({ ... })

    use RActiveMerchant, gateway, :checkout_path => '/foo', :purchase_path => '/bar'
