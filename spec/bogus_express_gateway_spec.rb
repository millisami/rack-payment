require File.dirname(__FILE__) + '/spec_helper'

describe ActiveMerchant::Billing::BogusExpressGateway do

  it '#setup_purchase(price, options) should require price, ip, return_url, cancel_return_url'

  it '#setup_purchase(price, options) should return a token'

  it '#redirect_url_for(token) should require a token and return an absolute URL'

end
