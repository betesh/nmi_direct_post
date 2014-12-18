require_relative 'spec_helper'
#require 'rspec/rails/extensions/active_record/base'

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
    expect(@transaction.save).to eq(true), "Transaction failed to save for the following reasons: #{@transaction.errors.messages.inspect}"
  end

  def expect_response_to_be response, response_code
    expect(@transaction.response).to eq(response), @transaction.inspect
    expect(@transaction.response_code).to eq(response_code), @transaction.inspect
  end

  def if_the_transaction_succeeds
    expect(@transaction.response).to eq(1), @transaction.inspect
  end

  def it_should_find_the_transaction
    @queried_transaction = NmiDirectPost::Transaction.find_by_transaction_id(@transaction.transaction_id)
    expect(@queried_transaction).not_to be_nil
    expect(@queried_transaction.amount).to eq @transaction.amount
    expect(@queried_transaction.customer_vault_id).to eq @transaction.customer_vault_id
    expect(@queried_transaction.customer_vault).not_to be_nil
    expect(@queried_transaction.customer_vault.first_name).to eq(@transaction.customer_vault.first_name)
  end

  it "should allow saving with a bang" do
    @transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call)
    expect{@transaction.save!}.not_to raise_error
  end

  it "should fail validation when no customer_vault_id and no transaction_id are given" do
    @transaction = NmiDirectPost::Transaction.new(:amount => amount.call)
    expect{@transaction.save!}.to raise_error(NmiDirectPost::TransactionNotSavedError)
  end

  it "should respond with a success code when given a valid customer_vault_id" do
    given_a_sale_for_customer_vault_id a_cc_customer_vault_id
    expect_response_to_be 1, 100
    expect(@transaction.response_text).to eq("SUCCESS"), @transaction.inspect
    expect(@transaction).to be_success, @transaction.inspect
  end

  it "should fail validation when given an invalid customer_vault_id" do
    @transaction = NmiDirectPost::Transaction.new(:customer_vault_id => 1000, :amount => amount.call)
    expect(@transaction.save).to eq(false)
    expect(@transaction.errors.size).to eq(1)
    expect(@transaction.errors[:customer_vault].size).to eq(1)
    expect(@transaction.errors[:customer_vault]).to include("Customer vault with the given customer_vault could not be found")
  end

  it "should find a sale" do
    given_a_sale_for_customer_vault_id a_cc_customer_vault_id
    if_the_transaction_succeeds
    it_should_find_the_transaction
    expect(@queried_transaction.type).to eq "sale"
  end

  it "should find a validate" do
    @transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => 0, :type => :validate)
    @transaction.save
    if_the_transaction_succeeds
    it_should_find_the_transaction
    expect(@queried_transaction.type).to eq @transaction.type
  end

  it "should raise an error when transaction_id is blank" do
    expect{ NmiDirectPost::Transaction.find_by_transaction_id("") }.to raise_error(StandardError, "TransactionID cannot be blank")
  end

  it "should raise an error when transaction is not found using instance" do
    expect{ NmiDirectPost::Transaction.new(:transaction_id => 12345) }.to raise_error(NmiDirectPost::TransactionNotFoundError, "No transaction found for TransactionID 12345")
  end

  it "should return nil when transaction is not found using class method" do
    expect(NmiDirectPost::Transaction.find_by_transaction_id(12345)).to be_nil
  end

  it "should add response, response_code and response to errors when charge cannot be saved" do
    transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => 0, :type => :validate)
    transaction.instance_variable_set("@password", '12345')
    expect(transaction.save).to eq(false)
    expect(transaction.errors.size).to eq(3), transaction.errors.inspect
    expect(transaction.errors[:response].size).to eq(1), transaction.errors[:response].inspect
    expect(transaction.errors[:response]).to include('3'), transaction.errors.inspect
    expect(transaction.errors[:response_code].size).to eq(1), transaction.errors[:response_code].inspect
    expect(transaction.errors[:response_code]).to include('300'), transaction.errors.inspect
    expect(transaction.errors[:response_text].size).to eq(1), transaction.errors[:response_text].inspect
    expect(transaction.errors[:response_text]).to include('Authentication Failed'), transaction.errors.inspect
  end

  describe "customer_vault" do
    it "should find when it exists" do
      @transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call)
      expect(@transaction.customer_vault).to have_same_attributes_as(NmiDirectPost::CustomerVault.find_by_customer_vault_id(a_cc_customer_vault_id))
    end

    it "should be nil when it doesn't exist" do
      @transaction = NmiDirectPost::Transaction.new(:customer_vault_id => '123456', :amount => amount.call)
      expect(@transaction.customer_vault).to be_nil
    end
  end

  describe "type" do
    describe "sale" do
      it "should allow non-zero amounts for credit card customer vaults" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call, :type => :sale)
        expect(transaction.save).to eq(true), transaction.errors.inspect
      end
      it "should not allow amount to be 0 for credit card customer vaults" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => 0, :type => :sale)
        expect(transaction.save).to eq(false)
        expect(transaction.errors.size).to eq(1)
        expect(transaction.errors[:amount].size).to eq(1)
        expect(transaction.errors[:amount]).to include('Amount cannot be 0 for a sale')
      end
      it "should allow non-zero amounts for checking account customer vaults" do
        expect(NmiDirectPost::Transaction.new(:customer_vault_id => a_checking_account_customer_vault_id, :amount => amount.call, :type => :sale).save).to eq(true)
      end
      it "should not allow amount to be 0 for checking account customer vaults" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_checking_account_customer_vault_id, :amount => 0, :type => :sale)
        expect(transaction.save).to eq(false)
        expect(transaction.errors.size).to eq(1)
        expect(transaction.errors[:amount].size).to eq(1)
        expect(transaction.errors[:amount]).to include('Amount cannot be 0 for a sale')
      end
      it "should allow non-zero amounts for credit card customer vaults when sale is implied" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call)
        expect(transaction.save).to eq(true), transaction.errors.inspect
      end
      it "should not allow amount to be 0 for credit card customer vaults when sale is implied" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => 0)
        expect(transaction.save).to eq(false)
        expect(transaction.errors.size).to eq(1)
        expect(transaction.errors[:amount].size).to eq(1)
        expect(transaction.errors[:amount]).to include('Amount cannot be 0 for a sale')
      end
      it "should allow non-zero amounts for checking account customer vaults when sale is implied" do
        expect(NmiDirectPost::Transaction.new(:customer_vault_id => a_checking_account_customer_vault_id, :amount => amount.call).save).to eq(true)
      end
      it "should not allow amount to be 0 for checking account customer vaults when sale is implied" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_checking_account_customer_vault_id, :amount => 0)
        expect(transaction.save).to eq(false)
        expect(transaction.errors.size).to eq(1)
        expect(transaction.errors[:amount].size).to eq(1)
        expect(transaction.errors[:amount]).to include('Amount cannot be 0 for a sale')
      end
    end

    describe "validate" do
      it "should not allow non-zero amounts" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call, :type => :validate)
        expect(transaction.save).to eq(false)
        expect(transaction.errors.size).to eq(1)
        expect(transaction.errors[:amount].size).to eq(1)
        expect(transaction.errors[:amount]).to include('Amount must be 0 when validating a credit card')
      end
      it "should allow amount to be 0" do
        expect(NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => 0, :type => :validate).save).to eq(true)
      end
      it "should not be allowed for checking account customer vaults" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_checking_account_customer_vault_id, :amount => 0, :type => :validate)
        expect(transaction.save).to eq(false)
        expect(transaction.errors.size).to eq(1)
        expect(transaction.errors[:type].size).to eq(1)
        expect(transaction.errors[:type]).to include('validate is not a valid action for a customer vault that uses a checking account')
      end
    end

    describe "auth" do
      it "should allow non-zero amounts for credit card customer vaults" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call, :type => :auth)
        expect(transaction.save).to eq(true), transaction.errors.inspect
      end
      it "should not allow amount to be 0 for credit card customer vaults" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => 0, :type => :auth)
        expect(transaction.save).to eq(false)
        expect(transaction.errors.size).to eq(1)
        expect(transaction.errors[:amount].size).to eq(1)
        expect(transaction.errors[:amount]).to include('Amount cannot be 0 for an authorization')
      end
      it "should not be allowed for checking account customer vaults" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_checking_account_customer_vault_id, :amount => amount.call, :type => :auth)
        expect(transaction.save).to eq(false)
        expect(transaction.errors.size).to eq(1)
        expect(transaction.errors[:type].size).to eq(1)
        expect(transaction.errors[:type]).to include('auth is not a valid action for a customer vault that uses a checking account')
      end
    end

    describe "void" do
      it "should be allowed for a pending sale" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call)
        transaction.save!
        expect(transaction.void!).to eq(true)
      end
      it "should not be allowed for validates" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => 0, :type => :validate)
        transaction.save!
        expect(transaction.void!).to eq(false)
        expect(transaction.errors.size).to eq(1), transaction.errors.inspect
        expect(transaction.errors[:type].size).to eq(1), transaction.errors.inspect
        expect(transaction.errors[:type]).to include('Void is only a valid action for a pending or unsettled authorization, or an unsettled sale')
      end
      it "should be allowed for authorizations when saved and voided on same instantiation" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call, :type => :auth)
        expect(transaction.save).to eq(true), transaction.inspect
        expect(transaction.void!).to eq(true), transaction.inspect
        expect(transaction.errors).to be_empty, transaction.errors.inspect
      end
      it "should be allowed for authorizations when found by transaction ID" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call, :type => :auth)
        transaction.save!
        transaction = NmiDirectPost::Transaction.find_by_transaction_id(transaction.transaction_id)
        expect(transaction.void!).to eq(true), transaction.inspect
        expect(transaction.errors).to be_empty, transaction.errors.inspect
      end
      it "should be allowed for authorizations when instantiated as a void" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call, :type => :auth)
        transaction.save!
        transaction = NmiDirectPost::Transaction.new(:transaction_id => transaction.transaction_id, :type => :void)
        expect(transaction.save).to eq(true), transaction.errors.inspect
        expect(transaction.errors).to be_empty, transaction.errors.inspect
      end
      it "should not be allowed for an unpersisted transaction" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call, :type => :auth)
        expect(transaction.void!).to eq(false), transaction.inspect
        expect(transaction.errors.size).to eq(1), transaction.errors.inspect
        expect(transaction.errors[:type].size).to eq(1), transaction.errors.inspect
        expect(transaction.errors[:type]).to include('Void is only a valid action for a transaction that has already been sent to NMI')
      end
      it "should not be allowed for a voided sale" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call)
        transaction.save!
        expect(transaction.void!).to eq(true)
        expect(transaction.void!).to eq(false)
        expect(transaction.errors.size).to eq(1), transaction.errors.inspect
        expect(transaction.errors[:type].size).to eq(1), transaction.errors.inspect
        expect(transaction.errors[:type]).to include('Void is only a valid action for a pending or unsettled authorization, or an unsettled sale')
      end
      it "should not be allowed for a voided auth" do
        transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call, :type => :auth)
        transaction.save!
        expect(transaction.void!).to eq(true)
        expect(transaction.void!).to eq(false)
        expect(transaction.errors.size).to eq(1), transaction.errors.inspect
        expect(transaction.errors[:type].size).to eq(1), transaction.errors.inspect
        expect(transaction.errors[:type]).to include('Void is only a valid action for a pending or unsettled authorization, or an unsettled sale')
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
      expect(@transaction.condition).to eq("pendingsettlement")
      expect(@transaction).to be_pending
      expect(@transaction).not_to be_cleared
      expect(@transaction.amount).to eq(@amount)
    end
    it "should be pending on a new CC charge" do
      given_a_cc_transaction
      expect(@transaction.condition).to eq("pendingsettlement")
      expect(@transaction).to be_pending
      expect(@transaction).not_to be_cleared
      expect(@transaction.amount).to eq(@amount)
    end
    it "should be approved on an existing CC charge" do
      transaction = NmiDirectPost::Transaction.find_by_transaction_id(TestCredentials::INSTANCE.cc_transaction)
      expect(transaction.condition).to eq("complete")
      expect(transaction).not_to be_pending
      expect(transaction).to be_cleared
    end
  end

  it "should not reload when transaction_id is missing" do
    transaction = NmiDirectPost::Transaction.new(:customer_vault_id => a_cc_customer_vault_id, :amount => amount.call)
    expect{transaction.reload}.not_to raise_error
  end
end
