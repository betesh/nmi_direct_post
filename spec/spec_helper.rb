require 'simplecov'
require 'nmi_direct_post'

Dir[("#{File.expand_path("#{__FILE__}/../support")}/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.order = "random"
end

RSpec::Matchers.define :have_same_attributes_as do |expected|
  match do |actual|
    actual.customer_vault_id == expected.customer_vault_id && [true] == (NmiDirectPost::CustomerVault::WHITELIST_ATTRIBUTES.collect { |a| actual.__send__(a) == expected.__send__(a) }).uniq
  end
  description do
    "'#{expected.inspect}'"
  end
end
