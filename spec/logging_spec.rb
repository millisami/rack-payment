require File.dirname(__FILE__) + '/spec_helper'

describe 'Logging' do

  before do
    @log_file = File.dirname(__FILE__) + '/rack-purchase.log'
    FileUtils.rm_f @log_file
    FileUtils.mkdir_p File.dirname(@log_file)

    @original_logger = Rack::Payment.logger
    Rack::Payment.logger = nil
  end

  after do
    FileUtils.rm_f @log_file
    Rack::Payment.logger = @original_logger
  end

  def log_text
    File.file?(@log_file) ? File.read(@log_file) : ''
  end

  def log_lines
    log_text.split("\n")
  end

  it 'should be able to set a logger on Rack::Purchase' do
    Rack::Payment.new.logger.should be_nil

    Rack::Payment.logger = Logger.new(@log_file)

    Rack::Payment.new.logger.should_not be_nil
    Rack::Payment.new.logger.should == Rack::Payment.logger

    Rack::Payment.logger = nil

    Rack::Payment.new.logger.should be_nil
  end

  it 'should be able to set a logger on a Rack::Purchase (can set it via a helper)' do
    payment = Rack::Payment.new.payment
    
    payment.logger = Logger.new @log_file
    File.file?(@log_file).should be_true # it writes out a line when it's created
    log_lines.length.should == 1

    payment.credit_card.update :first_name => 'remi', :last_name => 'taylor', :number => TEST_HELPER.cc_number.valid,
                               :cvv => '123', :year => '2015', :month => '01', :type => 'visa'
    payment.billing_address.update :name => 'remi taylor', :street => '101 Main St', :city => 'New York', :state => 'NY', 
                                   :country => 'USA', :zip => '12345'
    payment.amount = 15.95

    log_lines.length.should == 1 # still haven't tried to talk to the gateway or anything

    payment.purchase(:ip => '127.0.0.1').should be_true # make the purchase

    log_lines.length.should > 1 # should have written #authorize and #capture
    log = File.read(@log_file)
    log.should include('purchase')
    log.should include('1595')
    log.should include('authorize')
    log.should include('capture')
  end

end
