require_relative 'spec_helper'

describe NmiDirectPost::Base do
  def a_query
    NmiDirectPost::CustomerVault.find_by_customer_vault_id(a_cc_customer_vault_id)
  end
  let(:credentials) { TestCredentials::INSTANCE }
  let(:a_cc_customer_vault_id) { credentials.cc_customer }
  it "should raise exception when username is blank" do
    NmiDirectPost::Base.establish_connection('', credentials.nmi_password)
    expect{a_query}.to raise_error(StandardError, "Please set a username by calling NmiDirectPost::Base.establish_connection(ENV['NMI_USERNAME'], ENV['NMI_PASSWORD'])")
  end
  it "should raise exception when password is blank" do
    NmiDirectPost::Base.establish_connection(credentials.nmi_username, '')
    expect{a_query}.to raise_error(StandardError, "Please set a username by calling NmiDirectPost::Base.establish_connection(ENV['NMI_USERNAME'], ENV['NMI_PASSWORD'])")
  end
end
