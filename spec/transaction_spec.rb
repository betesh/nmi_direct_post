require_relative 'spec_helper'
require 'rspec/rails/extensions/active_record/base'

describe NmiDirectPost::Transaction do
  let(:a_cc_customer_vault_id) { TestCredentials::INSTANCE.cc_customer }
  let(:a_checking_account_customer_vault_id) { TestCredentials::INSTANCE.ach_customer }
  let(:amount) { lambda { @amount_generator.rand(50..500) } }

  before :all do
    credentials = TestCredentials::INSTANCE
    NmiDirectPost::Base.establish_connection(credentials.nmi_username, credentials.nmi_password)
    @amount_generator = Random.new
  end

  def given_a_sale_for_customer_vault_id customer_vault_id
    @transaction = NmiDirectPost::Transaction.new(:customer_vault_id => customer_vault_id, :amount => amount.call)
    @transaction.save.should be_true, "Transaction failed to save for the following reasons: #{@transaction.errors.messages.inspect}"
  end

  def expect_response_to_be response, response_code
    @transaction.response.should eq(response), @transaction.inspect
    @transaction.response_code.should eq(response_code), @transaction.inspect
  end

  def if_the_transaction_succeeds
    @transaction.response.should eq(1), @transaction.inspect
  end

  def it_should_find_the_transaction
    @queried_transaction = NmiDirectPost::Transaction.find_by_transaction_id(@transaction.transaction_id)
    @queried_transaction.should_not be_nil
    @queried_transaction.amount.should eq @transaction.amount
    @queried_transaction.customer_vault_id.should eq @transaction.customer_vault_id
    @queried_transaction.customer_vault.should_not be_nil
    @queried_transaction.customer_vault.first_name.should == @transaction.customer_vault.first_name
  end

  it "should allow saving with a bang" do
    @transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call)
    expect {@transaction.save!}.to_not raise_error
  end

  it "should fail validation when no customer_vault_id and no transaction_id are given" do
    @transaction = NmiDirectPost::Transaction.new(:amount => amount.call)
    expect {@transaction.save!}.to raise_error(NmiDirectPost::TransactionNotSavedError)
  end

  it "should respond with a success code when given a valid customer_vault_id" do
    given_a_sale_for_customer_vault_id a_cc_customer_vault_id
    expect_response_to_be 1, 100
    @transaction.response_text.should eq("SUCCESS"), @transaction.inspect
    @transaction.success.should be_true, @transaction.inspect
  end

  it "should fail validation when given an invalid customer_vault_id" do
    @transaction = NmiDirectPost::Transaction.new(:customer_vault_id => 1000, :amount => amount.call)
    @transaction.save.should be_false
    @transaction.should have(1).errors_on(:customer_vault)
    @transaction.errors_on(:customer_vault).should include("Customer vault with the given customer_vault could not be found")
  end

  it "should find a sale" do
    given_a_sale_for_customer_vault_id a_cc_customer_vault_id
    if_the_transaction_succeeds
    it_should_find_the_transaction
    @queried_transaction.type.should eq "sale"
  end

  it "should find a validate" do
    @transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => 0, :type => :validate)
    @transaction.save
    if_the_transaction_succeeds
    it_should_find_the_transaction
    @queried_transaction.type.should eq @transaction.type
  end

  it "should raise an error when transaction_id is blank" do
    expect { NmiDirectPost::Transaction.find_by_transaction_id("") }.to raise_error(StandardError, "TransactionID cannot be blank")
  end

  it "should raise an error when transaction is not found using instance" do
    expect { NmiDirectPost::Transaction.new(:transaction_id => 12345) }.to raise_error(NmiDirectPost::TransactionNotFoundError, "No transaction found for TransactionID 12345")
  end

  it "should return nil when transaction is not found using class method" do
    NmiDirectPost::Transaction.find_by_transaction_id(12345).should be_nil
  end

  it "should add response, response_code and response to errors when charge cannot be saved" do
    transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => 0, :type => :validate)
    transaction.instance_variable_set("@password", '12345')
    transaction.save.should be_false
    transaction.should have(3).errors, transaction.errors.inspect
    transaction.should have(1).errors_on(:response), transaction.errors[:response].inspect
    transaction.errors_on(:response).should include('3'), transaction.errors.inspect
    transaction.should have(1).errors_on(:response_code), transaction.errors[:response_code].inspect
    transaction.errors_on(:response_code).should include('300')
    transaction.should have(1).errors_on(:response_text), transaction.errors[:response_text].inspect
    transaction.errors_on(:response_text).should include('Authentication Failed')
  end

  describe "customer_vault" do
    it "should find when it exists" do
      @transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call)
      @transaction.customer_vault.should have_same_attributes_as(NmiDirectPost::CustomerVault.find_by_customer_vault_id(a_cc_customer_vault_id))
    end

    it "should be nil when it doesn't exist" do
      @transaction = NmiDirectPost::Transaction.new(:customer_vault_id => '123456', :amount => amount.call)
      @transaction.customer_vault.should be_nil
    end
  end

  describe "type" do
    describe "sale" do
      it "should allow non-zero amounts for credit card customer vaults" do
        NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call, :type => :sale).save.should be_true
      end
      it "should not allow amount to be 0 for credit card customer vaults" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => 0, :type => :sale)
        transaction.save.should be_false
        transaction.should have(1).error
        transaction.should have(1).errors_on(:amount)
        transaction.errors_on(:amount).should include('Amount cannot be 0 for a sale action')
      end
      it "should allow non-zero amounts for checking account customer vaults" do
        NmiDirectPost::Transaction.new(:customer_vault_id => a_checking_account_customer_vault_id, :amount => amount.call, :type => :sale).save.should be_true
      end
      it "should not allow amount to be 0 for checking account customer vaults" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_checking_account_customer_vault_id, :amount => 0, :type => :sale)
        transaction.save.should be_false
        transaction.should have(1).error
        transaction.should have(1).errors_on(:amount)
        transaction.errors_on(:amount).should include('Amount cannot be 0 for a sale action')
      end
      it "should allow non-zero amounts for credit card customer vaults when sale is implied" do
        NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call).save.should be_true
      end
      it "should not allow amount to be 0 for credit card customer vaults when sale is implied" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => 0)
        transaction.save.should be_false
        transaction.should have(1).error
        transaction.should have(1).errors_on(:amount)
        transaction.errors_on(:amount).should include('Amount cannot be 0 for a sale action')
      end
      it "should allow non-zero amounts for checking account customer vaults when sale is implied" do
        NmiDirectPost::Transaction.new(:customer_vault_id => a_checking_account_customer_vault_id, :amount => amount.call).save.should be_true
      end
      it "should not allow amount to be 0 for checking account customer vaults when sale is implied" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_checking_account_customer_vault_id, :amount => 0)
        transaction.save.should be_false
        transaction.should have(1).error
        transaction.should have(1).errors_on(:amount)
        transaction.errors_on(:amount).should include('Amount cannot be 0 for a sale action')
      end
    end

    describe "validate" do
      it "should not allow non-zero amounts" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call, :type => :validate)
        transaction.save.should be_false
        transaction.should have(1).error
        transaction.should have(1).errors_on(:amount)
        transaction.errors_on(:amount).should include('Amount must be 0 for a validate action')
      end
      it "should allow amount to be 0" do
        NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => 0, :type => :validate).save.should be_true
      end
      it "should not be allowed for checking account customer vaults" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_checking_account_customer_vault_id, :amount => 0, :type => :validate)
        transaction.save.should be_false
        transaction.should have(1).error
        transaction.should have(1).errors_on(:type)
        transaction.errors_on(:type).should include('validate is not a valid action for a customer vault that uses a checking account')
      end
    end
  end

  describe "condition" do
    def given_a_check_transaction
      transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_checking_account_customer_vault_id, :amount => amount.call)
      transaction.save!
      @amount = transaction.amount
      @transaction = NmiDirectPost::Transaction.find_by_transaction_id(transaction.transaction_id)
    end
    def given_a_cc_transaction
      transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call)
      transaction.save!
      @amount = transaction.amount
      @transaction = NmiDirectPost::Transaction.find_by_transaction_id(transaction.transaction_id)
    end
    it "should be pendingsettlement on a new check" do
      given_a_check_transaction
      @transaction.condition.should eq("pendingsettlement")
      @transaction.pending?.should be_true
      @transaction.cleared?.should be_false
      @transaction.amount.should == @amount
    end
    it "should be pending on a new CC charge" do
      given_a_cc_transaction
      @transaction.condition.should eq("pendingsettlement")
      @transaction.pending?.should be_true
      @transaction.cleared?.should be_false
      @transaction.amount.should == @amount
    end
    it "should be approved on an existing CC charge" do
      transaction = NmiDirectPost::Transaction.find_by_transaction_id(TestCredentials::INSTANCE.cc_transaction)
      transaction.condition.should eq("complete")
      transaction.pending?.should be_false
      transaction.cleared?.should be_true
    end
  end
end
