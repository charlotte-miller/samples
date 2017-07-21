require 'curb'
require 'payment_processing/error'

module PaymentProcessing::Gateway

  # Handles XML interaction w/ Verifone
  class Verifone
    @@supported_actions = [:validate, :preauth, :purchase, :postauth, :refund, :void]

    attr_accessor :action, :options, :request_xml
    attr_reader   :connection, :response_xml

    # _Primary Interface_
    # Example: PaymentProcessing::Gateway::Verifone.perform!(:preauth, amount:100, troutd:'IO9TRJM42' )
    # Option Notes:
    #   * 'amount' should be in cents
    #   * 'troutd' || 'swipe_data' || ('number', 'exp_month', 'exp_year') is required
    #   * 'swipe_data' is the raw string from an unincrypted card swipe
    #   * 'invoice' is the transaction's foreign key. Epoc Time.now used by default
    #   * 'dev_card' and 'dev_troutd' are "console-helper" options for using test data
    ###################################################################################
    def self.perform!( action, action_options={} )
      options = add_development_defaults_for( action_options )
      new( action, options ).deliver!
    end


    # Build and deliver your own
    ##############################
    def initialize( action, options={} )
      @action  = action.to_sym
      raise ArgumentError.new("#{@action} is not a @@suppored_action") unless @@supported_actions.include? @action
      @options = options

      # Build @request_xml
      xml = Builder::XmlMarkup.new(:indent => 2)
      xml.TRANSACTION do |xml|
        @transaction_xml = xml
        @transaction_xml.CLIENT_ID      account_info[:client_id]
        @transaction_xml.USER_ID        account_info[:user_id]
        @transaction_xml.USER_PW        account_info[:user_pw]
        @transaction_xml.MERCHANTKEY    account_info[:merchant_key]
        send( "#{@action}_xml_builder" )
      end
      @request_xml = xml.target!
      return self
    end

    # Send XML to Verifone
    def deliver!
      @connection = Curl::Easy.http_post(account_info[:url], @request_xml) { |req| req.headers['Content-Type'] = 'text/xml' }
      @response_xml = @connection.body_str
      check_for_errors  unless options[:skip_errors]
      return self
    end

    # Convenience Methods
    ######################
    def to_hash; @as_hash ||= HashWithIndifferentAccess.new( { request: Hash.from_xml(request_xml), response: Hash.from_xml(response_xml) }) ;end
    def summary; (resp = to_hash[:response][:RESPONSE])[:RESPONSE_TEXT] || resp[:RESULT] ;end
    def troutd;  to_hash[:response][:RESPONSE][:TROUTD] rescue nil ;end
    def invoice; to_hash[:request][:TRANSACTION][:INVOICE] ;end

    def status
      response = to_hash[:response]
      result = to_hash[:response][:RESPONSE][:RESULT].to_s rescue nil
      return case result
      when 'SUCCESS', 'CAPTURED', 'APPROVED', 'VOIDED', 'COMPLETED'
        'approved'
      when 'DECLINED'
        'decline'
      else
        if declined_response_code?(response[:RESPONSE][:RESULT_CODE])
          'decline'
        else
          nil
        end
      end
    end

    # Validate a troutd: creates then voids an actual charge
    def self.valid_troutd?( troutd )
      transaction = self.perform!(:postauth, {troutd: troutd, amount:1}) #charge 0.01
      transaction.action = :void
      !!transaction.deliver!
    rescue PaymentProcessing::InvalidTroutdError
      false
    end

  private

    def account_info
      @account_info ||= {
        url:          VerifoneConfig.url,
        client_id:    VerifoneConfig.client_id,
        user_id:      VerifoneConfig.user_id,
        user_pw:      VerifoneConfig.user_pw,
        merchant_key: VerifoneConfig.merchant_key
      }
    end

    def validate_xml_builder
      check_required_options({ :amount => :not_applicable, :troutd => :not_applicable })
      @transaction_xml.COMMAND  "PRE_AUTH"
      @options[:amount] = 0
      build_common_xml
    end

    def preauth_xml_builder
      check_required_options
      @transaction_xml.COMMAND  "PRE_AUTH"
      build_common_xml
    end

    def purchase_xml_builder
      check_required_options
      @transaction_xml.COMMAND  "SALE"
      build_common_xml
    end

    def postauth_xml_builder
      check_required_options({ :troutd => :required, :amount => :not_required })
      @transaction_xml.COMMAND  "COMPLETION"
      build_common_xml
    end

    def refund_xml_builder
      check_required_options({ :troutd => :required })
      @transaction_xml.COMMAND  "CREDIT"
      build_common_xml
    end

    def void_xml_builder
      check_required_options({ :amount => :not_applicable, :troutd => :required })
      @transaction_xml.COMMAND  "VOID"
      build_common_xml
    end

    # Enfource xml builder interface - failures raise an ArgumentError
    def check_required_options(overrides={})
      troutd_is_required            = overrides[:troutd] == :required
      troutd_is_present_and_allowed = @options[:troutd] && overrides[:troutd]!= :not_applicable
      amount_is_not_required        = [:not_required, :not_applicable].include? overrides[:amount]
      its_from_a_card_swipe         = @options[:swipe_data]

      # Human Readable
      @options.must_include  :troutd                          if     troutd_is_required
      @options.must_include( :number, :exp_month, :exp_year ) unless its_from_a_card_swipe or troutd_is_present_and_allowed
      @options.must_include  :amount                          unless amount_is_not_required
    end

    # Foundation xml for all actions
    def build_common_xml
      @transaction_xml.FUNCTION_TYPE  "PAYMENT"
      @transaction_xml.PAYMENT_TYPE   "CREDIT"
      @transaction_xml.PRESENT_FLAG   @options[ :swipe_data ] ? 3 : 1  # Card swiped || Card not present
      @transaction_xml.INVOICE        @options[ :invoice ] || Time.now.to_i
      @transaction_xml.TRANS_AMOUNT(  Money.new(@options[ :amount  ]).to_s  )   if @options[ :amount ]

      # Payment Information
      if @options[:troutd]
        tag = follow_on_transaction? ? 'REF_TROUTD' : 'TROUTD'
        @transaction_xml.tag! tag, @options[ :troutd ]

      elsif @options[ :swipe_data ]
        @transaction_xml.TRACK_DATA @options[ :swipe_data ]

      else
        @transaction_xml.ACCT_NUM   @options[ :number     ]
        @transaction_xml.EXP_MONTH  @options[ :exp_month  ]
        @transaction_xml.EXP_YEAR   @options[ :exp_year   ]
      end
    end

    # Converts Verifone error codes into PaymentProcessing::Errors
    # Skip this method w/ ``options[:skip_errors]``
    def check_for_errors
      response_hash = to_hash[:response]['RESPONSE']
      result_string = response_hash['RESULT'] || 'UNKNOWN'
      return unless ['ERROR', 'DECLINED', 'UNKNOWN'].include? result_string
      result_code   = response_hash['RESULT_CODE'].to_i
      verbose_error = "#{response_hash['RESPONSE_TEXT']}:\n#{response_xml}"

      raise PaymentProcessing::InvalidCreditCardError.new(verbose_error) if [93].include? result_code
      raise PaymentProcessing::InvalidRequestError.new(verbose_error)    if [-2, 1010, 3745].include? result_code
      raise PaymentProcessing::GatewayConnectionError.new(verbose_error) if [3100, 2029999].include? result_code
      raise PaymentProcessing::GatewayError.new(verbose_error)           if [30000].include? result_code
      raise PaymentProcessing::InvalidTroutdError.new(verbose_error)     if [3705].include? result_code

      unless declined_response_code?(result_code)
        raise PaymentProcessing::Error.new(verbose_error)                  # catch-all
      end
    end

    # Supports the use of a TROUTD to make a follow on transaciton
    def follow_on_transaction?
      @options[:troutd] && [:purchase, :preauth].include?( @action )
    end

    # Handy Test Data for Console - Development Only
    # Example:  PaymentProcessing::Gateway::Verifone.perform!( :purchase, :dev_troutd => true, :amount => 100 )
    def self.add_development_defaults_for(raw_action_options)
      return raw_action_options if !Rails.env.development? || ( [:dev_card, :dev_troutd] & raw_action_options.keys ).empty?

      test_card   = { :number => 4111111111111111,  :exp_month => 12, :exp_year => 15 }
      test_troutd = { troutd: perform!(:preauth, test_card.merge!({ amount:rand(1000) })).troutd } if raw_action_options[:dev_troutd]

      return raw_action_options.merge!(test_card)      if raw_action_options[:dev_card]
      return raw_action_options.merge!(test_troutd)    if raw_action_options[:dev_troutd]
    end

    # response codes that should be treated as declined charges
    # ie they should not raise errors but instead return a status 'decline' to allow the calling code to handle the decline appropriately
    # ex. Checkout should ask user to enter card again.  Charging auto extensions should save a decline.
    def declined_response_code?(response_code)
      # 6 - declined
      # 97 - invalid expiration / expired card
      [6, 97].include?(response_code.to_i)
    end
  end
end