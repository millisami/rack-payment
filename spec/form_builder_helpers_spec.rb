require File.dirname(__FILE__) + '/spec_helper'

describe Rack::Payment::Helper, '#form' do

  # <input name='authenticity_token' type='hidden' value='...' />
  it 'should be able to specify :auth_token' do
    payment = Rack::Payment.new.payment
    payment.form.should_not                    include("name='authenticity_token'", "value='1234'")
    payment.form(:auth_token => '1234').should include("name='authenticity_token'", "value='1234'")
  end

end

describe Rack::Payment::Helper, '#fields' do

  it 'should be able to get a credit card field (without a value)' do
    payment = Rack::Payment.new.payment
    # WARNING!  A hash is used in the background so we're not guaranteed order ... these need to be refactored because they may blow up sometimes!
    payment.fields[:credit_card][:first_name].should include("<input type='text'",
                                                             "autofocus='true'", 
                                                             "name='credit_card[first_name]'",
                                                             "id='credit_card_first_name'")

    payment.fields[:credit_card][:last_name].should include("<input type='text'",
                                                             "name='credit_card[last_name]'",
                                                             "id='credit_card_last_name'")
    
    payment.fields[:credit_card][:last_name ].should_not include("autofocus=true") # it's not the first field in the form

    payment.fields[:credit_card][:number].should include("<input type='text'",
                                                             "autocomplete='off'", 
                                                             "name='credit_card[number]'",
                                                             "id='credit_card_number'")

    payment.fields[:credit_card][:last_name ].should_not include("autocomplete='off'") # it's not a secure field
    payment.fields[:credit_card][:cvv       ].should     include("autocomplete='off'") # it is another secure field
  end

  it 'should be able to get a credit card field (with a value set from the Helper instance)' do
    payment = Rack::Payment.new.payment
    payment.credit_card.update :first_name => 'remi', :last_name => 'taylor', :number => TEST_HELPER.cc_number.valid,
                               :cvv => '123', :year => '2015', :month => '01', :type => 'visa'

    payment.fields[:credit_card][:first_name].should include("<input type='text'", 
                                                             "value='remi'", 
                                                             "autofocus='true'", 
                                                             "name='credit_card[first_name]'",
                                                             "id='credit_card_first_name'")
  end

  it 'should be able to get a credit card field (with a value passed in)' do
    payment = Rack::Payment.new.payment
    payment.credit_card.update :first_name => 'remi', :last_name => 'taylor', :number => TEST_HELPER.cc_number.valid,
                               :cvv => '123', :year => '2015', :month => '01', :type => 'visa'

    payment.fields(:credit_card => { :first_name => 'BOB' })[:credit_card][:first_name].should include("<input type='text'",
                                                                                                       "value='BOB'",
                                                                                                       "autofocus='true'",
                                                                                                       "name='credit_card[first_name]'",
                                                                                                       "id='credit_card_first_name'")
  end

end
