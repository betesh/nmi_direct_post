require_relative 'base'
require_relative 'customer_vault'

module NmiDirectPost
  class TransactionNotFoundError < StandardError; end

  class TransactionNotSavedError < StandardError; end

  class Transaction  < Base
    SAFE_PARAMS = [:customer_vault_id, :type, :amount]

    attr_reader *SAFE_PARAMS
    attr_reader :auth_code, :avs_response, :cvv_response, :order_id, :type, :dup_seconds, :condition
    attr_reader :transaction_id

    validates_presence_of :customer_vault_id, :amount, :unless => :'finding_by_transaction_id?', :message => "%{attribute} cannot be blank"
    validates_presence_of :customer_vault, :unless => 'customer_vault_id.blank?', :message => "%{attribute} with the given customer_vault could not be found"
    validates_inclusion_of :type, :in => ["sale", "auth", "capture", "void", "refund", "credit", "validate", "update", ""]
    validates_exclusion_of :type, :in => ["validate", "auth", "capture", "void"], :if => :'customer_vault_is_checking?', :message => "%{value} is not a valid action for a customer vault that uses a checking account"
    validates_numericality_of :amount, :equal_to => 0, :if => :'is_validate?', :message => "%{attribute} must be 0 when validating a credit card"
    validates_numericality_of :amount, :greater_than => 0, :if => :'is_sale?', :message => "%{attribute} cannot be 0 for a sale"
    validates_numericality_of :amount, :greater_than => 0, :if => :'is_auth?', :message => "%{attribute} cannot be 0 for an authorization"
    validate :voidable_transaction?, :if => :is_void?
    validate :persisted?, :if => :is_void?
    validate :save_successful?, :unless => 'response_text.blank?'

    def initialize(attributes)
      super
      @username = attributes[:username] if attributes[:username]
      @password = attributes[:password] if attributes[:password]
      @type, @amount = attributes[:type].to_s, attributes[:amount].to_f
      @transaction_id = attributes[:transaction_id].to_i if attributes[:transaction_id]
      @customer_vault_id = attributes[:customer_vault_id].to_i if attributes[:customer_vault_id]
      reload if (finding_by_transaction_id? && self.valid?)
      @type, @amount = attributes[:type].to_s, attributes[:amount].to_f if ['void', 'capture'].include?(attributes[:type].to_s)
    end

    def save
      return false if invalid?
      if condition.blank?
        if 'void' == type
          reload
          @type = 'void'
        end
      end
      _safe_params = safe_params
      logger.info { "Sending Direct Post Transaction to NMI: #{_safe_params}" }
      post([_safe_params, transaction_params].join('&'))
      valid?.tap { |_| reload if _ }
    end

    def save!
      save || raise(TransactionNotSavedError)
    end

    def self.find_by_transaction_id(transaction_id, username=nil, password=nil)
      raise StandardError, "TransactionID cannot be blank" if transaction_id.blank?
      NmiDirectPost.logger.debug { "Looking up NMI transaction by transaction_id(#{transaction_id})" }
      begin
        new(:transaction_id => transaction_id, username: username, password: password)
      rescue TransactionNotFoundError
        return nil
      end
    end

    def pending?
      'pendingsettlement' == condition
    end

    def cleared?
      "complete" == condition
    end

    def failed?
      "failed" == condition
    end

    def declined?
      2 == response
    end

    def void!
      @type='void'
      save
    end

    def customer_vault
      @customer_vault ||= CustomerVault.find_by_customer_vault_id(@customer_vault_id, @username, @password) unless @customer_vault_id.blank?
    end

    def reload
      get(transaction_params) if finding_by_transaction_id?
      self
    end

    private
      def safe_params
        generate_query_string(SAFE_PARAMS)
      end

      def transaction_params
        generate_query_string([AUTH_PARAMS, :transaction_id].flatten)
      end

      def get(query)
        hash = self.class.get(query)["transaction"]
        hash = hash.keep_if { |v| v['transaction_id'].to_s == self.transaction_id.to_s }.first if hash.is_a?(Array)
        raise TransactionNotFoundError, "No transaction found for TransactionID #{@transaction_id}" if hash.nil?
        @auth_code = hash["authorization_code"]
        @customer_vault_id = hash["customerid"].to_i
        @avs_response = hash["avs_response"]
        @condition = hash["condition"]
        action = hash["action"]
        action = action.last unless action.is_a?(Hash)
        @amount = action["amount"].to_f
        @type = action["action_type"]
        @response = action["success"].to_i if action.key?("success")
        @response_code = action["response_code"].to_i if action.key?("response_code")
        @response_text = action["response_text"]
      end

      def post(query)
        response = self.class.post(query)
        @response = response["response"].to_i if response.key?("response")
        @response_code = response["response_code"].to_i if response.key?("response_code")
        @response_text, @avs_response, @cvv_response = response["responsetext"], response["avsresponse"], response["cvvresponse"]
        @dup_seconds, @order_id, @auth_code = response["dup_seconds"], response["orderid"], response["authcode"]
        @transaction_id = response["transactionid"]
      end

      def customer_vault_is_checking?
        !customer_vault.blank? && customer_vault.checking?
      end

      def finding_by_transaction_id?
        !transaction_id.blank?
      end

      def is_validate?
        !finding_by_transaction_id? && ('validate' == type.to_s)
      end

      def is_sale?
        !finding_by_transaction_id? && (['sale', ''].include?(type.to_s))
      end

      def is_auth?
        !finding_by_transaction_id? && ('auth' == type.to_s)
      end

      def is_void?
        !customer_vault_is_checking? && ('void' == type.to_s)
      end

      def save_successful?
        return if (success? || declined?)
        self.errors.add(:response, response.to_s)
        self.errors.add(:response_code, response_code.to_s)
        self.errors.add(:response_text, response_text)
      end

      def voidable_transaction?
        self.errors.add(:type, "Void is only a valid action for a pending or unsettled authorization, or an unsettled sale") if (finding_by_transaction_id? && !['pending', 'pendingsettlement'].include?(condition)) unless condition.blank?
      end

      def persisted?
        self.errors.add(:type, "Void is only a valid action for a transaction that has already been sent to NMI") unless finding_by_transaction_id?
      end
  end
end
