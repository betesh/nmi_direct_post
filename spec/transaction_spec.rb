require_relative 'spec_helper'
#require 'rspec/rails/extensions/active_record/base'

describe NmiDirectPost::Transaction do
  let(:a_cc_customer_vault_id) { TestCredentials::INSTANCE.cc_customer }
  let(:a_checking_account_customer_vault_id) { TestCredentials::INSTANCE.ach_customer }
  let(:amount) { Random.rand(50.0..500.0).round(2) }
  let(:credentials) { TestCredentials::INSTANCE }
  let(:cc_implicit_sale) { NmiDirectPost::Transaction.new(customer_vault_id: a_cc_customer_vault_id, amount: amount) }
  let(:ach_implicit_sale) { NmiDirectPost::Transaction.new(customer_vault_id: a_checking_account_customer_vault_id, amount: amount) }
  let(:cc_validation) { NmiDirectPost::Transaction.new(customer_vault_id: a_cc_customer_vault_id, amount: 0, type: :validate) }

  before(:each) do
    NmiDirectPost::Base.establish_connection(credentials.nmi_username, credentials.nmi_password)
  end

  it "should allow saving with a bang" do
    expect{cc_implicit_sale.save!}.not_to raise_error
  end

  it "should fail validation when no customer_vault_id and no transaction_id are given" do
    transaction = NmiDirectPost::Transaction.new(amount: amount)
    expect{transaction.save!}.to raise_error(NmiDirectPost::TransactionNotSavedError)
  end

  it "should respond with a success code when given a valid customer_vault_id" do
    expect(cc_implicit_sale.save).to eq(true), "Transaction failed to save for the following reasons: #{cc_implicit_sale.errors.messages.inspect}"
    expect(cc_implicit_sale.response).to eq(1), cc_implicit_sale.inspect
    expect(cc_implicit_sale.response_code).to eq(100), cc_implicit_sale.inspect
    expect(cc_implicit_sale.response_text).to eq("SUCCESS"), cc_implicit_sale.inspect
    expect(cc_implicit_sale).to be_success, cc_implicit_sale.inspect
  end

  it "should fail validation when given an invalid customer_vault_id" do
    transaction = NmiDirectPost::Transaction.new(customer_vault_id: 1000, amount: amount)
    expect(transaction.save).to eq(false)
    expect(transaction.errors.size).to eq(1)
    expect(transaction.errors[:customer_vault].size).to eq(1)
    expect(transaction.errors[:customer_vault]).to include("Customer vault with the given customer_vault could not be found")
  end

  describe "finding an existing transaction" do
    let(:queried_transaction) { NmiDirectPost::Transaction.find_by_transaction_id(transaction.transaction_id) }

    def it_should_find_the_transaction
      expect(queried_transaction).not_to be_nil
      expect(queried_transaction.amount).to eq transaction.amount
      expect(queried_transaction.customer_vault_id).to eq transaction.customer_vault_id
      expect(queried_transaction.customer_vault).not_to be_nil
      expect(queried_transaction.customer_vault.first_name).to eq(transaction.customer_vault.first_name)
    end

    describe "a sale" do
      let(:transaction) { cc_implicit_sale }

      it "should be found" do
        expect(cc_implicit_sale.save).to eq(true), "Transaction failed to save for the following reasons: #{cc_implicit_sale.errors.messages.inspect}"
        expect(cc_implicit_sale.response).to eq(1), cc_implicit_sale.inspect
        it_should_find_the_transaction
        expect(queried_transaction.type).to eq "sale"
      end
    end

    describe "a validate" do
      let(:transaction) { cc_validation }

      it "should be found" do
        cc_validation.save
        expect(cc_validation.response).to eq(1), cc_validation.inspect
        it_should_find_the_transaction
        expect(queried_transaction.type).to eq cc_validation.type
      end
    end

    it "should raise an error when transaction_id is blank" do
      expect{ NmiDirectPost::Transaction.find_by_transaction_id("") }.to raise_error(StandardError, "TransactionID cannot be blank")
    end

    it "should raise an error when transaction is not found using instance" do
      expect{ NmiDirectPost::Transaction.new(transaction_id: 12345) }.to raise_error(NmiDirectPost::TransactionNotFoundError, "No transaction found for TransactionID 12345")
    end

    it "should return nil when transaction is not found using class method" do
      expect(NmiDirectPost::Transaction.find_by_transaction_id(12345)).to be_nil
    end
  end

  it "should add response, response_code and response to errors when charge cannot be saved" do
    cc_validation.instance_variable_set("@password", '12345')
    expect(cc_validation.save).to eq(false)
    expect(cc_validation.errors.size).to eq(3), cc_validation.errors.inspect
    expect(cc_validation.errors[:response].size).to eq(1), cc_validation.errors[:response].inspect
    expect(cc_validation.errors[:response]).to include('3'), cc_validation.errors.inspect
    expect(cc_validation.errors[:response_code].size).to eq(1), cc_validation.errors[:response_code].inspect
    expect(cc_validation.errors[:response_code]).to include('300'), cc_validation.errors.inspect
    expect(cc_validation.errors[:response_text].size).to eq(1), cc_validation.errors[:response_text].inspect
    expect(cc_validation.errors[:response_text]).to include('Authentication Failed'), cc_validation.errors.inspect
  end

  describe "customer_vault" do
    it "should find when it exists" do
      expect(cc_implicit_sale.customer_vault).to have_same_attributes_as(NmiDirectPost::CustomerVault.find_by_customer_vault_id(a_cc_customer_vault_id))
    end

    it "should be nil when it doesn't exist" do
      transaction = NmiDirectPost::Transaction.new(customer_vault_id: '123456', amount: amount)
      expect(transaction.customer_vault).to be_nil
    end
  end

  describe "type" do
    let(:cc_transaction) { NmiDirectPost::Transaction.new(customer_vault_id: a_cc_customer_vault_id, amount: amount, type: transaction_type) }
    let(:cc_transaction_amount_0) { NmiDirectPost::Transaction.new(customer_vault_id: a_cc_customer_vault_id, amount: 0, type: transaction_type) }
    let(:ach_transaction) { NmiDirectPost::Transaction.new(customer_vault_id: a_checking_account_customer_vault_id, amount: amount, type: transaction_type) }
    let(:ach_transaction_amount_0) { NmiDirectPost::Transaction.new(customer_vault_id: a_checking_account_customer_vault_id, amount: 0, type: transaction_type) }

    describe "sale" do
      let(:transaction_type) { :sale }
      it "should allow non-zero amounts for credit card customer vaults" do
        expect(cc_transaction.save).to eq(true), cc_transaction.errors.inspect
      end
      it "should not allow amount to be 0 for credit card customer vaults" do
        expect(cc_transaction_amount_0.save).to eq(false)
        expect(cc_transaction_amount_0.errors.size).to eq(1)
        expect(cc_transaction_amount_0.errors[:amount].size).to eq(1)
        expect(cc_transaction_amount_0.errors[:amount]).to include('Amount cannot be 0 for a sale')
      end
      it "should allow non-zero amounts for checking account customer vaults" do
        expect(ach_transaction.save).to eq(true)
      end
      it "should not allow amount to be 0 for checking account customer vaults" do
        expect(ach_transaction_amount_0.save).to eq(false)
        expect(ach_transaction_amount_0.errors.size).to eq(1)
        expect(ach_transaction_amount_0.errors[:amount].size).to eq(1)
        expect(ach_transaction_amount_0.errors[:amount]).to include('Amount cannot be 0 for a sale')
      end
      it "should allow non-zero amounts for credit card customer vaults when sale is implied" do
        expect(cc_implicit_sale.save).to eq(true), cc_implicit_sale.errors.inspect
      end
      it "should not allow amount to be 0 for credit card customer vaults when sale is implied" do
        transaction = NmiDirectPost::Transaction.new(customer_vault_id: a_cc_customer_vault_id, amount: 0)
        expect(transaction.save).to eq(false)
        expect(transaction.errors.size).to eq(1)
        expect(transaction.errors[:amount].size).to eq(1)
        expect(transaction.errors[:amount]).to include('Amount cannot be 0 for a sale')
      end
      it "should allow non-zero amounts for checking account customer vaults when sale is implied" do
        expect(ach_implicit_sale.save).to eq(true)
      end
      it "should not allow amount to be 0 for checking account customer vaults when sale is implied" do
        transaction = NmiDirectPost::Transaction.new(customer_vault_id: a_checking_account_customer_vault_id, amount: 0)
        expect(transaction.save).to eq(false)
        expect(transaction.errors.size).to eq(1)
        expect(transaction.errors[:amount].size).to eq(1)
        expect(transaction.errors[:amount]).to include('Amount cannot be 0 for a sale')
      end
    end

    describe "validate" do
      let(:transaction_type) { :validate }
      it "should not allow non-zero amounts" do
        expect(cc_transaction.save).to eq(false)
        expect(cc_transaction.errors.size).to eq(1)
        expect(cc_transaction.errors[:amount].size).to eq(1)
        expect(cc_transaction.errors[:amount]).to include('Amount must be 0 when validating a credit card')
      end
      it "should allow amount to be 0" do
        expect(cc_transaction_amount_0.save).to eq(true)
      end
      it "should not be allowed for checking account customer vaults" do
        expect(ach_transaction_amount_0.save).to eq(false)
        expect(ach_transaction_amount_0.errors.size).to eq(1)
        expect(ach_transaction_amount_0.errors[:type].size).to eq(1)
        expect(ach_transaction_amount_0.errors[:type]).to include('validate is not a valid action for a customer vault that uses a checking account')
      end
    end

    describe "auth" do
      let(:transaction_type) { :auth }
      it "should allow non-zero amounts for credit card customer vaults" do
        expect(cc_transaction.save).to eq(true), cc_transaction.errors.inspect
      end
      it "should not allow amount to be 0 for credit card customer vaults" do
        expect(cc_transaction_amount_0.save).to eq(false)
        expect(cc_transaction_amount_0.errors.size).to eq(1)
        expect(cc_transaction_amount_0.errors[:amount].size).to eq(1)
        expect(cc_transaction_amount_0.errors[:amount]).to include('Amount cannot be 0 for an authorization')
      end
      it "should not be allowed for checking account customer vaults" do
        expect(ach_transaction.save).to eq(false)
        expect(ach_transaction.errors.size).to eq(1)
        expect(ach_transaction.errors[:type].size).to eq(1)
        expect(ach_transaction.errors[:type]).to include('auth is not a valid action for a customer vault that uses a checking account')
      end
    end

    let(:cc_auth) { NmiDirectPost::Transaction.new(customer_vault_id: a_cc_customer_vault_id, amount: amount, type: :auth) }

    describe "void" do
      it "should be allowed for a pending sale" do
        cc_implicit_sale.save!
        expect(cc_implicit_sale.void!).to eq(true)
      end
      it "should not be allowed for validates" do
        cc_validation.save!
        expect(cc_validation.void!).to eq(false)
        expect(cc_validation.errors.size).to eq(1), cc_validation.errors.inspect
        expect(cc_validation.errors[:type].size).to eq(1), cc_validation.errors.inspect
        expect(cc_validation.errors[:type]).to include('Void is only a valid action for a pending or unsettled authorization, or an unsettled sale')
      end
      it "should be allowed for authorizations when saved and voided on same instantiation" do
        expect(cc_auth.save).to eq(true), cc_auth.inspect
        expect(cc_auth.void!).to eq(true), cc_auth.inspect
        expect(cc_auth.errors).to be_empty, cc_auth.errors.inspect
      end
      it "should be allowed for authorizations when found by transaction ID" do
        cc_auth.save!
        void = NmiDirectPost::Transaction.find_by_transaction_id(cc_auth.transaction_id)
        expect(void.void!).to eq(true), void.inspect
        expect(void.errors).to be_empty, void.errors.inspect
      end
      it "should be allowed for authorizations when instantiated as a void" do
        cc_auth.save!
        void = NmiDirectPost::Transaction.new(transaction_id: cc_auth.transaction_id, type: :void)
        expect(void.save).to eq(true), cc_auth.errors.inspect
        expect(void.errors).to be_empty, cc_auth.errors.inspect
      end
      it "should not be allowed for an unpersisted transaction" do
        expect(cc_auth.void!).to eq(false), cc_auth.inspect
        expect(cc_auth.errors.size).to eq(1), cc_auth.errors.inspect
        expect(cc_auth.errors[:type].size).to eq(1), cc_auth.errors.inspect
        expect(cc_auth.errors[:type]).to include('Void is only a valid action for a transaction that has already been sent to NMI')
      end

      def expect_error_on_void_for(transaction)
        expect(transaction.errors.size).to eq(1), transaction.errors.inspect
        expect(transaction.errors[:type].size).to eq(1), transaction.errors.inspect
        expect(transaction.errors[:type]).to include('Void is only a valid action for a pending or unsettled authorization, or an unsettled sale')
      end

      it "should not be allowed for a voided sale" do
        cc_implicit_sale.save!
        expect(cc_implicit_sale.void!).to eq(true)
        expect(cc_implicit_sale.void!).to eq(false)
        expect_error_on_void_for(cc_implicit_sale)
        void = NmiDirectPost::Transaction.new(transaction_id: cc_implicit_sale.transaction_id, type: :void)
        expect(void.save).to eq(false)
        expect_error_on_void_for(void)
      end
      it "should not be allowed for a voided auth" do
        cc_auth.save!
        expect(cc_auth.void!).to eq(true)
        expect(cc_auth.void!).to eq(false)
        expect_error_on_void_for(cc_auth)

        void = NmiDirectPost::Transaction.new(transaction_id: cc_auth.transaction_id, type: :void)
        expect(void.save).to eq(false)
        expect_error_on_void_for(void)
      end
    end

    describe "refund" do
      let(:refund_amount) { ((amount - 6) / 3.0 + 9).round(2) }
      it "should not be allowed for a pending sale" do
        cc_implicit_sale.save!
        expect(cc_implicit_sale.refund!(refund_amount)).to eq(false)
        expect(cc_implicit_sale.errors.size).to eq(1), cc_implicit_sale.errors.inspect
        expect(cc_implicit_sale.errors[:condition].size).to eq(1), cc_implicit_sale.errors.inspect
        expect(cc_implicit_sale.errors[:condition]).to include("Refund is only a valid action for authorization that already were captured and settled, or sales that already settled.  Current condition: pendingsettlement")
      end
      it "should not be allowed for validates" do
        cc_validation.save!
        expect(cc_validation.refund!(refund_amount)).to eq(false)
        expect(cc_validation.errors.size).to eq(1), cc_validation.errors.inspect
        expect(cc_validation.errors[:type].size).to eq(1), cc_validation.errors.inspect
        expect(cc_validation.errors[:type]).to include("Refund is only a valid action for authorization that already were captured and settled, or sales that already settled")
      end
      it "should be allowed for authorizations when found by transaction ID" do
        cc_auth.save!
        refund = NmiDirectPost::Transaction.find_by_transaction_id(cc_auth.transaction_id)
        expect(refund.refund!(refund_amount)).to eq(true), refund.inspect
        expect(refund.errors).to be_empty, refund.errors.inspect
      end
      it "should be allowed for authorizations when instantiated as a refund" do
        cc_auth.save!
        refund = NmiDirectPost::Transaction.new(transaction_id: cc_auth.transaction_id, type: :refund, amount: refund_amount)
        expect(refund.save).to eq(true), cc_auth.errors.inspect
        expect(refund.errors).to be_empty, cc_auth.errors.inspect
      end
      it "should not be allowed for an unpersisted transaction" do
        expect(cc_auth.refund!(refund_amount)).to eq(false), cc_auth.inspect
        expect(cc_auth.errors.size).to eq(1), cc_auth.errors.inspect
        expect(cc_auth.errors[:type].size).to eq(1), cc_auth.errors.inspect
        expect(cc_auth.errors[:type]).to include('Void is only a valid action for a transaction that has already been sent to NMI')
      end

      def expect_error_on_void_for(transaction)
        expect(transaction.errors.size).to eq(1), transaction.errors.inspect
        expect(transaction.errors[:type].size).to eq(1), transaction.errors.inspect
        expect(transaction.errors[:type]).to include('Void is only a valid action for a pending or unsettled authorization, or an unsettled sale')
      end

      it "should not be allowed for a voided sale" do
        cc_implicit_sale.save!
        expect(cc_implicit_sale.refund!(refund_amount)).to eq(true)
        expect(cc_implicit_sale.refund!(refund_amount)).to eq(false)
        expect_error_on_void_for(cc_implicit_sale)
        void = NmiDirectPost::Transaction.new(transaction_id: cc_implicit_sale.transaction_id, type: :void)
        expect(void.save).to eq(false)
        expect_error_on_void_for(void)
      end
      it "should not be allowed for a voided auth" do
        cc_auth.save!
        expect(cc_auth.refund!(refund_amount)).to eq(true)
        expect(cc_auth.refund!(refund_amount)).to eq(false)
        expect_error_on_void_for(cc_auth)

        void = NmiDirectPost::Transaction.new(transaction_id: cc_auth.transaction_id, type: :void)
        expect(void.save).to eq(false)
        expect_error_on_void_for(void)
      end
    end
  end

  describe "condition" do
    it "should be pendingsettlement on a new check" do
      ach_implicit_sale.save!
      transaction = NmiDirectPost::Transaction.find_by_transaction_id(ach_implicit_sale.transaction_id)
      expect(transaction.condition).to eq("pendingsettlement")
      expect(transaction).to be_pending
      expect(transaction).not_to be_cleared
      expect(transaction.amount).to eq(amount)
    end
    it "should be pending on a new CC charge" do
      cc_implicit_sale.save!
      transaction = NmiDirectPost::Transaction.find_by_transaction_id(cc_implicit_sale.transaction_id)
      expect(transaction.condition).to eq("pendingsettlement")
      expect(transaction).to be_pending
      expect(transaction).not_to be_cleared
      expect(transaction.amount).to eq(amount)
    end
    it "should be approved on an existing CC charge" do
      transaction = NmiDirectPost::Transaction.find_by_transaction_id(TestCredentials::INSTANCE.cc_transaction)
      expect(transaction.condition).to eq("complete")
      expect(transaction).not_to be_pending
      expect(transaction).to be_cleared
    end
  end

  it "should not reload when transaction_id is missing" do
    expect{cc_implicit_sale.reload}.not_to raise_error
  end
end
