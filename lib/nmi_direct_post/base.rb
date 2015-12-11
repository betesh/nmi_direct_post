require 'net/https'
require 'openssl'

require 'active_support/concern'
require 'active_support/callbacks'
require 'active_model/conversion'
require 'active_model/validator'
require 'active_model/callbacks'
require 'active_support/core_ext/module/delegation'
require 'active_model/naming'
require 'active_model/translation'
require 'active_model/validations'
require 'active_model/errors'
require 'active_support/core_ext/object/blank'
require 'addressable/uri'
require_relative 'logger'

module NmiDirectPost
  class Base
    POST_URI = "https://secure.nmi.com/api/transact.php"
    GET_URI = "https://secure.nmi.com/api/query.php"

    AUTH_PARAMS = [:username, :password]
    attr_reader *AUTH_PARAMS
    attr_reader :response, :response_text, :response_code

    include ActiveModel::Validations
    include ActiveModel::Conversion
    validates_presence_of :username, :password

    def initialize(attributes)
      @username = attributes[:username] || attributes["username"] || self.class.username
      @password = attributes[:password] || attributes["password"] || self.class.password
    end

    def persisted?
      false
    end

    def success?
      1 == self.response
    end

    def logger
      NmiDirectPost.logger
    end

    class << self
      NO_CONNECTION = "Please set a username by calling NmiDirectPost::Base.establish_connection(ENV['NMI_USERNAME'], ENV['NMI_PASSWORD'])"
      def establish_connection(username, password)
        @username, @password = username, password
      end

      def username
        @username || (in_base? ? raise_no_connection_error : superclass.username).tap { |_| raise_no_connection_error if _.blank? }
      end

      def password
        @password || (in_base? ? raise_no_connection_error : superclass.password).tap { |_| raise_no_connection_error if _.blank? }
      end

      def generate_query_string(attributes, target = self)
        ((attributes.reject { |attr| target.__send__(attr).blank? }).collect { |attr| "#{attr}=#{Addressable::URI.escape(target.__send__(attr).to_s)}"}).join('&')
      end

      def get(query)
        uri = [GET_URI, query].join('?')
        data = get_http_response(uri).body
        Hash.from_xml(data)["nm_response"]
      end

      def post(query)
        uri = [POST_URI, query].join('?')
        data = get_http_response(uri)
        Addressable::URI.parse([POST_URI, data.body].join('?')).query_values
      end

      protected
        def get_http_response(uri)
          request = Net::HTTP::Get.new(uri)
          url = URI.parse(uri)
          http = Net::HTTP.new(url.host, url.port)
          http.use_ssl = true
          http.ssl_version = :TLSv1_2
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.request(request)
        end

        def in_base?
          'Object' == superclass.name
        end

        def raise_no_connection_error
          raise(StandardError, NO_CONNECTION)
        end
    end

    protected
      def generate_query_string(attributes)
        self.class.generate_query_string(attributes, self)
      end
  end
end
