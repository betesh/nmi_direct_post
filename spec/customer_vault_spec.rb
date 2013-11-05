require_relative 'spec_helper'

describe NmiDirectPost::CustomerVault do
  def get_new_email
    "someone#{Random.rand(1..1000)}@example.com"
  end

  CV = NmiDirectPost::CustomerVault
  let(:a_cc_customer_vault_id) { TestCredentials::INSTANCE.cc_customer }
  let(:a_cc_customer) { CV.find_by_customer_vault_id(a_cc_customer_vault_id) }
  let(:a_checking_account_customer_vault_id) { TestCredentials::INSTANCE.ach_customer }
  let(:a_checking_account_customer) { CV.find_by_customer_vault_id(a_checking_account_customer_vault_id) }

  before :all do
    credentials = TestCredentials::INSTANCE
    NmiDirectPost::Base.establish_connection(credentials.nmi_username, credentials.nmi_password)
  end

  describe "find_by_customer_vault_id" do
    it "should find a customer vault" do
      a_cc_customer.customer_vault_id.should eq(a_cc_customer_vault_id)
      a_cc_customer.first_name.should_not be_nil
      a_cc_customer.last_name.should_not be_nil
      a_cc_customer.email.should_not be_nil
    end

    it "should raise exception when customer_vault_id is blank" do
      expect{CV.find_by_customer_vault_id("")}.to raise_error(StandardError, "CustomerVaultID cannot be blank")
    end

    it "should return exception when no customer is found" do
      CV.find_by_customer_vault_id("123456").should be_nil
    end
  end

  describe "create" do
    it "should not create a customer vault when no payment info is specified" do
      new_email = get_new_email
      @customer = CV.new(:first_name => "George", :last_name => "Washington")
      @customer.create.should be_false
      @customer.errors.full_messages.should eq(["Billing information Either :cc_number (a credit card number) and :cc_exp (the credit card expiration date), or :check_account, :check_aba (the routing number of the checking account) and :check_name (a nickname for the account), must be present"])
    end

    it "should not create a customer vault when a customer valut id is already present" do
      new_email = get_new_email
      @customer = CV.new(:first_name => "George", :last_name => "Washington", :cc_number => "4111111111111111", :cc_exp => "06/16", :customer_vault_id => a_cc_customer_vault_id)
      @customer.create.should be_false
      @customer.errors.full_messages.should eq(["Customer vault You cannot specify a Customer vault ID when creating a new customer vault.  NMI will assign one upon creating the record"])
    end

    it "should create a customer vault with an automatically assigned customer_vault_id when a credit card number and expiration date are specified" do
      new_email = get_new_email
      @customer = CV.new(:first_name => "George", :last_name => "Washington", :cc_number => "4111111111111111", :cc_exp => "06/16")
      @customer.create.should be_true
      @customer.destroy.success?.should be_true
      @customer.cc_exp.should eq("06/16")
    end

    it "should create a customer vault with an automatically assigned customer_vault_id when a checking account number and routing number are specified" do
      new_email = get_new_email
      @customer = CV.new(:first_name => "George", :last_name => "Washington", :check_aba => "123123123", :check_account => "123123123", :check_name => "my checking account")
      @customer.create.should be_true
      @customer.destroy.success?.should be_true
    end

    [[:cc_number, :check_name], [:cc_number, :check_account], [:cc_number, :check_aba], [:cc_exp, :check_name], [:cc_exp, :check_account], [:cc_exp, :check_aba]].each do |attrs|
      attributes = {:first_name => "George", :last_name => "Washington", :cc_number => "4111111111111111", :cc_exp => "06/16", :check_aba => "123123123", :check_account => "123123123", :check_name => "my checking account"}
      attributes.delete(attrs.first)
      attributes.delete(attrs.last)
      it "should not create a customer vault when missing #{attrs.first} and #{attrs.last}" do
        new_email = get_new_email
        @customer = CV.new(attributes)
        @customer.create.should be_false
        @customer.errors.full_messages.should eq(["Billing information Either :cc_number (a credit card number) and :cc_exp (the credit card expiration date), or :check_account, :check_aba (the routing number of the checking account) and :check_name (a nickname for the account), must be present"])
      end
    end
  end

  describe "save" do
    it "should update the customer vault with new shipping_email when shipping_email is set before calling save!" do
      new_email = get_new_email
      a_cc_customer.shipping_email = new_email
      a_cc_customer.save!
      a_cc_customer.response_text.should eq("Customer Update Successful")
      a_cc_customer.success?.should be_true
      a_cc_customer.shipping_email.should eq(new_email)
      a_cc_customer.reload.shipping_email.should eq(new_email)
    end
  end

  describe "update" do
    it "should update the customer vault with new merchant_defined_fields" do
      new_field_1 = Random.rand(1..1000)
      new_field_2 = Random.rand(1..1000)
      a_cc_customer.update!(:merchant_defined_field_1 => new_field_1, :merchant_defined_field_2 => new_field_2)
      a_cc_customer.response_text.should eq("Customer Update Successful")
      a_cc_customer.success?.should be_true
      a_cc_customer.reload
      a_cc_customer.merchant_defined_field_1.should eq(new_field_1.to_s)
      a_cc_customer.merchant_defined_field_2.should eq(new_field_2.to_s)
    end

    it "should update the customer vault with new shipping_email when shipping_email is passed to update!" do
      new_email = get_new_email
      a_cc_customer.update!(:shipping_email => new_email)
      a_cc_customer.response_text.should eq("Customer Update Successful")
      a_cc_customer.success?.should be_true
      a_cc_customer.shipping_email.should eq(new_email)
      a_cc_customer.reload.shipping_email.should eq(new_email)
    end

    it "should not update the customer vault with new shipping_email when shipping_email is set before calling update!" do
      new_email = get_new_email
      new_address = "#{Random.rand(1..1000)} Sesame Street"
      old_email = a_cc_customer.shipping_email
      a_cc_customer.shipping_email = new_email
      a_cc_customer.update!(:shipping_address_1 => new_address)
      a_cc_customer.response_text.should eq("Customer Update Successful")
      a_cc_customer.success?.should be_true
      a_cc_customer.shipping_email.should eq(new_email)
      a_cc_customer.reload.shipping_email.should eq(old_email)
    end

    it "should not allow updating the customer_vault_id" do
      new_email = get_new_email
      expect{a_cc_customer.update!(:customer_vault_id => '')}.to raise_error(NmiDirectPost::MassAssignmentSecurity::Error, "Cannot mass-assign the following attributes: customer_vault_id")
    end

    it "should not interfere with other set variables" do
      new_email = get_new_email
      new_address = "#{Random.rand(1..1000)} Sesame Street"
      old_email = a_cc_customer.shipping_email
      a_cc_customer.shipping_email = new_email
      a_cc_customer.update!(:shipping_address_1 => new_address)
      a_cc_customer.response_text.should eq("Customer Update Successful")
      a_cc_customer.success?.should be_true
      a_cc_customer.shipping_email.should eq(new_email)
      a_cc_customer.save!
      a_cc_customer.reload.shipping_email.should eq(new_email)
    end
  end

  describe "reload" do
    it "should not reload if customer vault id is missing" do
      @customer = CV.new({})
      @customer.customer_vault_id.should be_nil
      @customer.reload
      @customer.success?.should be_false
      @customer.response.should be_nil
      @customer.errors.full_messages.should eq(["Customer vault You must specify a Customer vault ID when looking up an individual customer vault"])
    end
  end

  describe "first/last/all" do
    before(:all) do
      @all_ids = CV.all_ids
    end
    it "should get all ids" do
      @all_ids.should be_a(Array)
      @all_ids.should eq(@all_ids.uniq)
      @all_ids.each do |id|
        id.should be_a(Fixnum)
      end
    end

    it "should get the first customer vault" do
      expected = CV.find_by_customer_vault_id(@all_ids.first)
      first = CV.first
      first.should be_a(CV)
      first.should have_same_attributes_as(expected)
    end

    it "should get the last customer vault" do
      expected = CV.find_by_customer_vault_id(@all_ids.last)
      last = CV.last
      last.should be_a(CV)
      last.should have_same_attributes_as(expected)
    end

    it "should get all customer vaults" do
      customers = CV.all
      customers.count.should eq(@all_ids.count)
      customers.each do |customer|
        customer.should be_a(CV)
        customer.customer_vault_id.should_not be_nil
      end
    end
  end

  describe "cc_hash" do
    it "should not be settable" do
      a_cc_customer.respond_to?('cc_hash=').should be_false
    end
    it "should be a string on a CC customer" do
      a_cc_customer.cc_hash.should be_a(String)
    end
    it "should be nil on a checking customer" do
      a_checking_account_customer.cc_hash.should be_nil
    end
    it "should not be allowed in a mass assignment update" do
      expect{a_cc_customer.update!(:cc_hash => 'abcdefg')}.to raise_error(NmiDirectPost::MassAssignmentSecurity::Error, 'Cannot mass-assign the following attributes: cc_hash')
    end
    it "should not be allowed when initialized" do
      expect{CV.new(:first_name => "George", :last_name => "Washington", :cc_number => "4111111111111111", :cc_exp => "06/16", :cc_hash => 'abcdefg')}.to raise_error(NmiDirectPost::MassAssignmentSecurity::Error, 'Cannot mass-assign the following attributes: cc_hash')
    end
  end

  describe "check_hash" do
    it "should not be settable" do
      a_cc_customer.respond_to?('check_hash=').should be_false
    end
    it "should be a string on a CC customer" do
      a_checking_account_customer.check_hash.should be_a(String)
    end
    it "should be nil on a checking customer" do
      a_cc_customer.check_hash.should be_nil
    end
    it "should not be allowed in a mass assignment update" do
      expect{a_cc_customer.update!(:check_hash => 'abcdefg')}.to raise_error(NmiDirectPost::MassAssignmentSecurity::Error, 'Cannot mass-assign the following attributes: check_hash')
    end
    it "should not be allowed when initialized" do
      expect{CV.new(:first_name => "George", :last_name => "Washington", :cc_number => "4111111111111111", :cc_exp => "06/16", :check_hash => 'abcdefg')}.to raise_error(NmiDirectPost::MassAssignmentSecurity::Error, 'Cannot mass-assign the following attributes: check_hash')
    end
  end

  describe "checking?" do
    it "should be true for a checking account customer" do
      a_checking_account_customer.checking?.should be_true
    end
    it "should be false for a CC customer" do
      a_cc_customer.checking?.should be_false
    end
  end

  describe "credit_card?" do
    it "should be true for a CC customer" do
      a_cc_customer.credit_card?.should be_true
    end
    it "should be false for a checking account customer" do
      a_checking_account_customer.credit_card?.should be_false
    end
  end
end
