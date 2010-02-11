require File.dirname(__FILE__) + '/spec_helper'

%w( rubygems dm-core dm-aggregates ).each {|lib| require lib }
DataMapper.setup :testing, 'sqlite3::memory:'

class DataMapperUser
  include DataMapper::Resource
  include Rack::Payment::Billable::DataMapper

  def self.default_repository_name() :testing end

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
      DataMapperUser.destroy_all!

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
      scheduled_payment.charge_at.should == Time.parse('01/31/2021') # next charge_at
    end

    it 'should be able to process payments'

    it 'should be able to get successful / failed charges'

  end

  describe 'ActiveRecord' do
    it 'should also work ...'
  end

end
