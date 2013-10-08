require 'simplecov'
require 'nmi_direct_post'

Dir[("#{File.expand_path("#{__FILE__}/../support")}/**/*.rb")].each { |f| require f }

RSpec.configure do |config|
  config.order = "random"
end
