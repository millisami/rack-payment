require File.dirname(__FILE__) + '/spec_helper'

%w( rubygems dm-core dm-aggregates rack-payment/billable/datamapper ).each {|lib| require lib }
DataMapper.setup :default, 'sqlite3::memory:'

class DataMapperUser
  include DataMapper::Resource
  include Rack::Payment::Billable::DataMapper

  property :id,   Serial
  property :name, String
end

DataMapper.auto_upgrade!

# NOTE
# by default, if you include the module, it should look in the appropriate 
# places for a configuration file for Rack::Payment
#
# we'll figure it out more as we use it more ...

describe 'Persistant Credit Card' do

  describe 'DataMapper' do

    before do
      DataMapperUser.count.should == 0
      @user = DataMapperUser.create :name => 'remi'
      DataMapperUser.count.should == 1
    end
  
    it 'should be able to persist a credit card on a model' do

      @user.credit_card.number.should be_nil
      @user.credit_card.number = '1234567890'
      @user.credit_card.number.should == '1234567890'

      DataMapperUser.get(@user.id).credit_card.number.should be_nil
      @user.save
      DataMapperUser.get(@user.id).credit_card.number.should == '1234567890'

      @user.credit_card_number.should_not == '1234567890'
      @user.credit_card_number.should == Rack::Payment.new.encrypt('1234567890')
      # ^ it uses the default if you don't specify configuration options
    end

    it 'should be able to schedule a payment' do
      @user.scheduled_payments.should be_empty

      @user.schedule_payment! 9.95, Time.parse('01/31/2021')

      @user.scheduled_payments.should_not be_empty
      @user.scheduled_payments.length.should == 1

      scheduled_payment = @user.scheduled_payments.first
      scheduled_payment.amount.should    == 9.95
      scheduled_payment.due_at.should == Time.parse('01/31/2021') # next charge_at
    end

    it 'should be able to process payments' do
      DataMapperUser.future_payments.count.should == 0
      DataMapperUser.due_payments.count.should    == 0

      @user.schedule_payment! 9.95, Time.parse('01/31/2021')

      @user.scheduled_payments.length.should == 1
      DataMapperUser.future_payments.count.should == 1
      DataMapperUser.due_payments.count.should    == 0

      @user.schedule_payment! 1.23, Time.parse('01/31/2009') # past due

      @user.scheduled_payments.length.should == 2
      DataMapperUser.future_payments.count.should == 1
      DataMapperUser.due_payments.count.should    == 1

      @user.completed_payments.length.should == 0
      payments = DataMapperUser.process_due_payments!
      @user.reload
      @user.completed_payments.length.should == 1

      payments.length.should == 1
      payments.first.amount.should == 1.23
      payments.first.due_at.should == Time.parse('01/31/2009')

      @user.completed_payments.length.should == 1
      payment = @user.completed_payments.first
      payment.amount.should == 1.23
      payment.due_at.should == Time.parse('01/31/2009')
      # other fields to check?  response and whatnot?

      @user.scheduled_payments.length.should == 1
      DataMapperUser.future_payments.count.should == 1
      DataMapperUser.due_payments.count.should    == 0 # it has been processed!
    end

    it 'should be able to process payments for a particular user'

    it 'should be able to get successful / failed charges'

  end

  describe 'ActiveRecord' do
    it 'should also work ...'
  end

end
