def fill_in_invalid_credit_card fields = {}
  fill_in_credit_card({:number => '2'}.merge(fields))
end

def fill_in_valid_credit_card fields = {}
  fill_in_credit_card({:number => '1'}.merge(fields))
end

def fill_in_credit_card fields = {}
  { 
    :first_name       => 'remi',
    :last_name        => 'taylor',
    :number           => '1',     # 1 is valid using the BogusGateway
    :cvv              => '123',
    :expiration_month => '01',
    :expiration_year  => '2015',
    :type             => 'visa'
  }.merge(fields).each { |key, value| fill_in "credit_card_#{key}", :with => value.to_s }
end

def fill_in_valid_billing_address
  { 
    :name     => 'remi',
    :address1 => '123 Chunky Bacon St.',
    :city     => 'Magical Land',
    :state    => 'NY',
    :country  => 'US',
    :zip      => '12345'
  }.each { |key, value| fill_in "billing_address_#{key}", :with => value.to_s }
end
