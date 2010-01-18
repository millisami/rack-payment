# This is used for testing the example web applications using your own gateway (running in test mode)

GATEWAY = ActiveMerchant::Billing::Base.gateway('paypal').new(
  :login     => 'seller_1234_biz_api1.domain.com',
  :password  => '1234567890',
  :signature => 'qwerty'
)
