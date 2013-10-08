require_relative 'spec_helper'

RSpec::Matchers.define :have_same_attributes_as do |expected|
  match do |actual|
    actual.customer_vault_id == expected.customer_vault_id && [true] == (NmiDirectPost::CustomerVault::WHITELIST_ATTRIBUTES.collect { |a| actual.__send__(a) == expected.__send__(a) }).uniq
  end
  description do
    "'#{expected.inspect}'"
  end
end

describe NmiDirectPost::CustomerVault do
  def get_new_email
    "someone#{Random.rand(1..1000)}@example.com"
  end

  CV = NmiDirectPost::CustomerVault
  let(:known_customer_vault_id) { TestCredentials::INSTANCE.known_customer_vault_id }

  before :all do
    credentials = TestCredentials::INSTANCE
    NmiDirectPost::Base.establish_connection(credentials.nmi_username, credentials.nmi_password)
  end

  describe "find_by_customer_vault_id" do
    it "should find a customer vault" do
      @customer = CV.find_by_customer_vault_id(known_customer_vault_id)
      @customer.customer_vault_id.should eq(known_customer_vault_id)
      @customer.first_name.should_not be_nil
      @customer.last_name.should_not be_nil
      @customer.email.should_not be_nil
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
      @customer = CV.new(:first_name => "George", :last_name => "Washington", :cc_number => "4111111111111111", :cc_exp => "06/16", :customer_vault_id => known_customer_vault_id)
      @customer.create.should be_false
      @customer.errors.full_messages.should eq(["Customer vault You cannot specify a Customer vault ID when creating a new customer vault.  NMI will assign one upon creating the record"])
    end

    it "should create a customer vault with an automatically assigned customer_vault_id when a credit card number and expiration date are specified" do
      new_email = get_new_email
      @customer = CV.new(:first_name => "George", :last_name => "Washington", :cc_number => "4111111111111111", :cc_exp => "06/16")
      @customer.create.should be_true
      @customer.destroy.success.should be_true
      @customer.cc_exp.should eq("06/16")
    end

    it "should create a customer vault with an automatically assigned customer_vault_id when a checking account number and routing number are specified" do
      new_email = get_new_email
      @customer = CV.new(:first_name => "George", :last_name => "Washington", :check_aba => "123123123", :check_account => "123123123", :check_name => "my checking account")
      @customer.create.should be_true
      @customer.destroy.success.should be_true
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
      @customer = CV.find_by_customer_vault_id(known_customer_vault_id)
      @customer.shipping_email = new_email
      @customer.save!
      @customer.response_text.should eq("Customer Update Successful")
      @customer.success.should be_true
      @customer.shipping_email.should eq(new_email)
      @customer.reload.shipping_email.should eq(new_email)
    end
  end

  describe "update" do
    it "should update the customer vault with new shipping_email when shipping_email is passed to update!" do
      new_email = get_new_email
      @customer = CV.find_by_customer_vault_id(known_customer_vault_id)
      @customer.update!(:shipping_email => new_email)
      @customer.response_text.should eq("Customer Update Successful")
      @customer.success.should be_true
      @customer.shipping_email.should eq(new_email)
      @customer.reload.shipping_email.should eq(new_email)
    end

    it "should not update the customer vault with new shipping_email when shipping_email is set before calling update!" do
      new_email = get_new_email
      new_address = "#{Random.rand(1..1000)} Sesame Street"
      @customer = CV.find_by_customer_vault_id(known_customer_vault_id)
      old_email = @customer.shipping_email
      @customer.shipping_email = new_email
      @customer.update!(:shipping_address_1 => new_address)
      @customer.response_text.should eq("Customer Update Successful")
      @customer.success.should be_true
      @customer.shipping_email.should eq(new_email)
      @customer.reload.shipping_email.should eq(old_email)
    end

    it "should not allow updating the customer_vault_id" do
      new_email = get_new_email
      @customer = CV.find_by_customer_vault_id(known_customer_vault_id)
      expect{@customer.update!(:customer_vault_id => '')}.to raise_error(NmiDirectPost::MassAssignmentSecurity::Error, "Cannot mass-assign the following attributes: customer_vault_id")
    end

    it "should not interfere with other set variables" do
      new_email = get_new_email
      new_address = "#{Random.rand(1..1000)} Sesame Street"
      @customer = CV.find_by_customer_vault_id(known_customer_vault_id)
      old_email = @customer.shipping_email
      @customer.shipping_email = new_email
      @customer.update!(:shipping_address_1 => new_address)
      @customer.response_text.should eq("Customer Update Successful")
      @customer.success.should be_true
      @customer.shipping_email.should eq(new_email)
      @customer.save!
      @customer.reload.shipping_email.should eq(new_email)
    end
  end

  describe "reload" do
    it "should not reload if customer vault id is missing" do
      @customer = CV.new({})
      @customer.customer_vault_id.should be_nil
      @customer.reload
      @customer.success.should be_false
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
end
