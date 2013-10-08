class TestCredentials
  attr_reader :nmi_username, :nmi_password, :known_customer_vault_id
  def initialize nmi_username, nmi_password, known_customer_vault_id
    @nmi_username, @nmi_password, @known_customer_vault_id = nmi_username, nmi_password, known_customer_vault_id
  end
  credentials_file = File.expand_path("#{__FILE__}/../credentials.rb")
  unless File.exists?(credentials_file)
    puts "Please configure your NMI application credentials by copying #{credentials_file}.example to #{credentials_file} and configuring the required values there appropriately."
    exit
  end
end
