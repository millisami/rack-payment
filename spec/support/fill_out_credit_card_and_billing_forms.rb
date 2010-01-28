#
# #authorize
#   1: Successful Authorization
#   2: Failed Authorization
#   3: Raises Exception
#
# # capture
#   1: Failed Capture
#   2: Raises Exception
#   *: Successful Capture
#
TEST_HELPER = OpenStruct.new({
  :cc_number => OpenStruct.new({
    :valid   => '1',
    :invalid => '2',
    :boom    => '3'
  }),

  :auth => OpenStruct.new({
    :valid   => '123',
    :invalid => '1',
    :boom    => '2'
  })
})

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
  }.merge(fields).each { |key, value| fill_in "credit_card_#{key}", :with => value.to_s }

  select '01',   :from => :credit_card_expiration_month
  select '2015', :from => :credit_card_expiration_year
  # select 'Visa', :from => 'credit_card_type' # <-- this fucking HATES me and refuses to work!
  fill_in :credit_card_type, :with => 'visa'
end

def billing_address_hash
  { 
    :name     => 'remi',
    :address1 => '123 Chunky Bacon St.',
    :city     => 'Magical Land',
    :state    => 'NY',
    :country  => 'US',
    :zip      => '12345'
  }
end

def fill_in_valid_billing_address
  billing_address_hash.each { |key, value| fill_in "billing_address_#{key}", :with => value.to_s }
end
