require_relative 'spec_helper'

describe NmiDirectPost::Transaction do
  let(:known_customer_vault_id) { TestCredentials::INSTANCE.known_customer_vault_id }
  let(:amount) { lambda { @amount_generator.rand(50..500) } }

  before :all do
    credentials = TestCredentials::INSTANCE
    NmiDirectPost::Transaction.establish_connection(credentials.nmi_username, credentials.nmi_password)
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
  end

  it "should allow saving with a bang" do
    @transaction = NmiDirectPost::Transaction.new(:customer_vault_id => known_customer_vault_id, :amount => amount.call)
    expect {@transaction.save!}.to_not raise_error
  end

  it "should fail validation when no customer_vault_id and no transaction_id are given" do
    @transaction = NmiDirectPost::Transaction.new(:amount => amount.call)
    expect {@transaction.save!}.to raise_error(NmiDirectPost::TransactionNotSavedError)
  end

  it "should respond with a success code when given a valid customer_vault_id" do
    given_a_sale_for_customer_vault_id known_customer_vault_id
    expect_response_to_be 1, 100
    @transaction.response_text.should eq("SUCCESS"), @transaction.inspect
    @transaction.success.should be_true, @transaction.inspect
  end

  it "should respond with a decline code when given an invalid customer_vault_id" do
    given_a_sale_for_customer_vault_id 1000
    expect_response_to_be 3, 300
    @transaction.response_text.include?("Invalid Customer Vault ID specified").should be_true, @transaction.inspect
    @transaction.success.should be_false, @transaction.inspect
  end

  it "should find a sale" do
    given_a_sale_for_customer_vault_id known_customer_vault_id
    if_the_transaction_succeeds
    it_should_find_the_transaction
    @queried_transaction.type.should eq "sale"
  end

  it "should find a validate" do
    @transaction = NmiDirectPost::Transaction.new(:customer_vault_id => known_customer_vault_id, :amount => 0, :type => :validate)
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

end
