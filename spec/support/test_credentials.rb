class TestCredentials
  attr_reader :nmi_username, :nmi_password, :cc_customer, :ach_customer
  def initialize nmi_username, nmi_password, cc_customer, ach_customer
    @nmi_username, @nmi_password, @cc_customer, @ach_customer = nmi_username, nmi_password, cc_customer, ach_customer
  end
  credentials_file = File.expand_path("#{__FILE__}/../credentials.rb")
  unless File.exists?(credentials_file)
    puts "Please configure your NMI application credentials by copying #{credentials_file}.example to #{credentials_file} and configuring the required values there appropriately."
    exit
  end
end
