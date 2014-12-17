require 'active_model/serialization'
require 'active_model/serializers/xml'
require_relative 'base'

module NmiDirectPost
  class CustomerVaultNotFoundError < StandardError; end

  class CustomerVaultInvalidPostActionError < StandardError; end

  module MassAssignmentSecurity
    class Error < StandardError; end
  end

  class CustomerVault < Base
    private
      NIL = "DYkMd6Nu1r3wpNNkDw8CMbpydEhohJYX3TluvhSsqFjDqvr34a4k2BL4pBY8"
      def self.attr_accessor_with_tracking_of_changes(*list)
        list.each do |attr|
          attr_reader attr
          define_method("#{attr}=") do |val|
            (@attributes_to_save ||=[]) << attr
            instance_variable_set("@#{attr}", val)
          end
        end
      end
    public
    READ_ONLY_ATTRIBUTES = [:check_hash, :cc_hash]
    attr_reader *READ_ONLY_ATTRIBUTES
    attr_reader :customer_vault_id, :customer_vault, :report_type

    MERCHANT_DEFINED_FIELDS = 20.times.collect { |i| :"merchant_defined_field_#{i+1}" }
    WHITELIST_ATTRIBUTES = [:id, :first_name, :last_name, :address_1, :address_2, :company, :city, :state, :postal_code, :country, :email, :phone, :fax, :cell_phone, :customertaxid, :website, :shipping_first_name, :shipping_last_name, :shipping_address_1, :shipping_address_2, :shipping_company, :shipping_city, :shipping_state, :shipping_postal_code, :shipping_country, :shipping_email, :shipping_carrier, :tracking_number, :shipping_date, :shipping, :cc_number, :cc_exp, :cc_issue_number, :check_account, :check_aba, :check_name, :account_holder_type, :account_type, :sec_code, :processor_id, :cc_bin, :cc_start_date] + MERCHANT_DEFINED_FIELDS
    attr_accessor_with_tracking_of_changes *WHITELIST_ATTRIBUTES

    validate :billing_information_present?, :if => Proc.new { |record| :add_customer == record.customer_vault }
    validates_presence_of :customer_vault_id, :message => "You must specify a %{attribute} ID when looking up an individual customer vault", :if => Proc.new { |record| :customer_vault == record.report_type }
    validates_presence_of :customer_vault_id, :message => "You must specify a %{attribute} ID when updating a customer vault", :if => Proc.new { |record| :update_customer == record.customer_vault }
    validates_inclusion_of :customer_vault_id, :in => [nil], :message => "You cannot specify a %{attribute} ID when creating a new customer vault.  NMI will assign one upon creating the record",
        :if => Proc.new { |record| :add_customer == record.customer_vault }

    def initialize(attributes)
      super()
      if attributes[:customer_vault_id].blank?
        set_attributes(attributes.dup) unless attributes.empty?
      else
        @customer_vault_id = attributes[:customer_vault_id].to_i
        reload
      end
    end

    def create
      post_action(:add)
      self.success?
    end

    def update!(attributes)
      begin
        set_attributes(attributes)
        post_action(:update)
      ensure
        @attributes_to_save.delete_if {|v| @attributes_to_update.include?(v) } if @attributes_to_save
        @attributes_to_update = nil
      end
      self
    end

    def save!
      post_action(:update)
      reload
      self.success?
    end

    def destroy
      post_action(:delete)
      self
    end

    def reload
      @report_type = :customer_vault
      if invalid?
        @report_type = nil
        return self
      end
      begin
        safe_params = customer_vault_instance_params
        logger.debug { "Loading NMI customer vault from customer_vault_id(#{customer_vault_id}) using query: #{safe_params}" }
        response = self.class.get(self.class.all_params(safe_params))["customer_vault"]
        raise CustomerVaultNotFoundError, "No record found for customer vault ID #{self.customer_vault_id}" if response.nil?
        attributes = response["customer"]
        READ_ONLY_ATTRIBUTES.each do |a|
          val = (attributes.delete(a.to_s) { NIL })
          instance_variable_set("@#{a}",val) unless NIL == val
        end
        set_attributes(attributes.tap { |_| _.delete("customer_vault_id") })
      ensure
        @report_type = nil
        @attributes_to_update = nil
        @attributes_to_save = nil
      end
      self
    end

    def credit_card?
      !@cc_hash.blank?
    end

    def checking?
      !@check_hash.blank?
    end

    def find!
      begin
        @report_type = :customer_vault
        safe_params = generate_query_string(MERCHANT_DEFINED_FIELDS + [:last_name, :email, :report_type]) # These are the only fields you can use when looking up without a customer_vault_id
        logger.info { "Querying NMI customer vault: #{safe_params}" }
        @customer_vault_id = self.class.get(self.class.all_params(safe_params))['customer_vault'][0]['customer_vault_id'] # This assumes there is only 1 result.
        # TODO: When there are multiple results, we don't know which one you want.  Maybe raise an error in that case?
        reload
      ensure
        @report_type = nil
      end
    end

    class << self
      attr_reader :report_type

      def find_by_customer_vault_id(customer_vault_id)
        raise StandardError, "CustomerVaultID cannot be blank" if customer_vault_id.blank?
        begin
          new(:customer_vault_id => customer_vault_id)
        rescue CustomerVaultNotFoundError
          return nil
        end
      end

      def first(limit = 1)
        limit(0, limit-1).first
      end

      def last(limit = 1)
        limit(-limit, -1).first
      end

      def all_ids
        @report_type = :customer_vault
        safe_params = generate_query_string([:report_type])
        NmiDirectPost.logger.debug { "Loading all NMI customer vaults using query: #{safe_params}" }
        begin
          customers = get(all_params(safe_params))["customer_vault"]
        ensure
          @report_type = nil
        end
        return [] if customers.nil?
        customers = customers["customer"]
        customers.collect { |customer| customer["customer_vault_id"].to_i }
      end

      def all
        limit
      end

      def all_params(safe_params)
        [safe_params, generate_query_string(Base::AUTH_PARAMS)].join('&')
      end

      private
        def limit(first = 0, last = -1)
          all_ids[first..last].collect { |id| new(:customer_vault_id => id) }
        end
    end

    private
      def customer_vault_instance_params
        generate_query_string([:customer_vault, :customer_vault_id, :report_type])
      end

      def post(safe_params)
        logger.info { "Sending Direct Post to NMI: #{safe_params}" }
        response = self.class.post(self.class.all_params(safe_params))
        @response, @response_text, @response_code = response["response"].to_i, response["responsetext"], response["response_code"].to_i
        @customer_vault_id = response["customer_vault_id"].to_i if :add_customer == self.customer_vault
      end

      def set_attributes(attributes)
        @attributes_to_update = []
        merchant_defined_fields = []
        WHITELIST_ATTRIBUTES.each do |a|
          val = (attributes.delete(a.to_s) { NIL })
          val = (attributes.delete(a) { NIL }) if NIL == val
          merchant_defined_field_index = a.to_s.split('merchant_defined_field_')[1]
          if (!merchant_defined_field_index.nil? && NIL == val && attributes.key?('merchant_defined_field'))
            val = attributes['merchant_defined_field'][merchant_defined_field_index.to_i - 1] || NIL
            merchant_defined_fields << (merchant_defined_field_index.to_i - 1) unless NIL == val
          end
          unless NIL == val
            self.__send__("#{a}=", val)
            @attributes_to_update << a
          end
        end
        merchant_defined_fields.each do |i|
          attributes['merchant_defined_field'][i] = nil
          attributes.delete('merchant_defined_field') if [nil] == attributes['merchant_defined_field'].uniq
        end
        @id = @id.to_i if @id
        raise MassAssignmentSecurity::Error, "Cannot mass-assign the following attributes: #{attributes.keys.join(", ")}" unless attributes.empty?
      end

      def billing_information_present?
        self.errors.add(:billing_information, "Either :cc_number (a credit card number) and :cc_exp (the credit card expiration date), or :check_account, :check_aba (the routing number of the checking account) and :check_name (a nickname for the account), must be present") if (missing_cc_information? && missing_checking_information?)
      end

      def missing_checking_information?
        self.check_account.blank? || self.check_aba.blank? || self.check_name.blank?
      end

      def missing_cc_information?
        self.cc_exp.blank? || self.cc_number.blank?
      end

      def post_action(action)
        @customer_vault = :"#{action}_customer"
        safe_params = case action.to_sym
        when :delete
          customer_vault_instance_params
        when :add
          [customer_vault_instance_params, generate_query_string(WHITELIST_ATTRIBUTES)].join("&")
        when :update
          [customer_vault_instance_params, generate_query_string(@attributes_to_update || @attributes_to_save)].join("&")
        else
          raise CustomerVaultInvalidPostActionError, "#{action} is not a valid post action.  NmiDirectPost allows the following post actions: :add, :update, :delete"
        end
        begin
          post(safe_params) if valid?
        ensure
          @customer_vault = nil
        end
      end
  end
end
