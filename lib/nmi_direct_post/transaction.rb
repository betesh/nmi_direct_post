require_relative 'base'

module NmiDirectPost
  class TransactionNotFoundError < StandardError; end

  class TransactionNotSavedError < StandardError; end

  class Transaction  < Base
    SAFE_PARAMS = [:customer_vault_id, :type, :amount]

    attr_reader *SAFE_PARAMS
    attr_reader :auth_code, :avs_response, :cvv_response, :order_id, :type, :dup_seconds, :customer_vault, :condition
    attr_reader :transaction_id

    validates_presence_of :customer_vault_id, :amount, :unless => :'finding_by_transaction_id?', :message => "%{attribute} cannot be blank"
    validates_presence_of :customer_vault, :unless => :'customer_vault_id.blank?', :message => "%{attribute} with the given customer_vault could not be found"
    validates_inclusion_of :type, :in => ["sale", "authorization", "capture", "void", "refund", "credit", "validate", "update", ""]
    validates_exclusion_of :type, :in => ["validate"], :if => :'customer_vault_is_checking?', :message => "%{value} is not a valid action for a customer vault that uses a checking account"
    validates_numericality_of :amount, :equal_to => 0, :if => :'is_validate?', :message => "%{attribute} must be 0 for a validate action"
    validates_numericality_of :amount, :greater_than => 0, :if => :'is_sale?', :message => "%{attribute} cannot be 0 for a sale action"

    def initialize(attributes)
      super()
      @type, @amount = attributes[:type].to_s, attributes[:amount].to_f
      @transaction_id = attributes[:transaction_id].to_i if attributes[:transaction_id]
      @customer_vault_id = attributes[:customer_vault_id].to_i if attributes[:customer_vault_id]
      @customer_vault = CustomerVault.find_by_customer_vault_id(@customer_vault_id) unless @customer_vault_id.blank?
      get(transaction_params) if (!@transaction_id.blank? && self.valid?)
    end

    def save
      return false if self.invalid?
      _safe_params = safe_params
      puts "Sending Direct Post Transaction to NMI: #{_safe_params}"
      post([_safe_params, transaction_params].join('&'))
      true
    end

    def save!
      save || raise(TransactionNotSavedError)
    end

    def self.find_by_transaction_id(transaction_id)
      raise StandardError, "TransactionID cannot be blank" if transaction_id.blank?
      puts "Looking up NMI transaction by transaction_id(#{transaction_id})"
      begin
        new(:transaction_id => transaction_id)
      rescue TransactionNotFoundError
        return nil
      end
    end

    def pending?
      'pendingsettlement' == @condition
    end

    def cleared?
      "complete" == @condition
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
        raise TransactionNotFoundError, "No transaction found for TransactionID #{@transaction_id}" if hash.nil?
        @auth_code = hash["authorization_code"]
        @customer_vault_id = hash["customerid"].to_i
        @avs_response = hash["avs_response"]
        @amount = hash["action"]["amount"].to_f
        @type = hash["action"]["action_type"]
        @response = hash["action"]["success"].to_i
        @response_code = hash["action"]["response_code"].to_i
        @response_text = hash["action"]["response_text"]
        @condition = hash["condition"]
      end

      def post(query)
        response = self.class.post(query)
        @response, @response_text, @avs_response, @cvv_response, @response_code = response["response"].to_i, response["responsetext"], response["avsresponse"], response["cvvresponse"], response["response_code"].to_i
        @dup_seconds, @order_id, @auth_code = response["dup_seconds"], response["orderid"], response["authcode"]
        @transaction_id = response["transactionid"]
      end

      def customer_vault_is_checking?
        !customer_vault.blank? && customer_vault.checking?
      end

      def finding_by_transaction_id?
        !transaction_id.nil?
      end

      def is_validate?
        !finding_by_transaction_id? && ('validate' == type.to_s)
      end

      def is_sale?
        !finding_by_transaction_id? && (['sale', ''].include?(type.to_s))
      end
  end
end
