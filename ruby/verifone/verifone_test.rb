require 'test_helper'
require 'payment_processing/error'

module PaymentProcessing::Gateway
  class VerifoneTest < ActiveSupport::TestCase
    setup do
      # HTTP from Fixture
      WebMock.disable_net_connect!
      VCR.insert_cassette('verifone_test_api', :match_requests_on => [:uri, :body], :record => :none) # use :new_episodes to add new tests
      Timecop.freeze("2012-06-18 14:22:55 -0700") # freezes the generation of 'invoice'

      # Payment Types
      @valid_card = {
        number:    4111111111111111,
        exp_month: 12,
        exp_year:  15,
        amount:    100,
        invoice:   54324 }
      @valid_card_swipe = {
        swipe_data:'%B4111111111111111^MILLER II/CHARLES ^1403101000000000012059409000000?;4111111111111111=140310112059409?',
        amount:    100,
        invoice:   54325 }
      @static_troutd = {amount: 100, troutd: '12345', invoice:54324 }
      @valid_troutd = lambda {|real_troutd| @static_troutd.merge!({troutd:real_troutd})}
    end

    teardown do
      Timecop.return
      VCR.eject_cassette
      WebMock.allow_net_connect!
    end

    context ".perform!" do
      setup {@response = nil} #evade closure by leaking the response from the assert_nothing_raised &block

      context ":validate -" do
        context "required options" do
          should "ignore amount" do
            assert_nothing_raised { Verifone.new( :validate, @valid_card ) }
            @valid_card.delete :amount
            assert_nothing_raised { Verifone.new( :validate, @valid_card ) }
          end

          should "always require card_information" do
            assert_nothing_raised { Verifone.new( :validate, @valid_card ) }
            assert_nothing_raised { Verifone.new( :validate, @valid_card_swipe ) }
            assert_raise( ArgumentError ) { Verifone.new( :validate )}                 # no payment info
            assert_raise( ArgumentError ) { Verifone.new( :validate, @static_troutd )} # using a troutd
          end
        end

        should "successfully validate the card with card-number" do
          assert_nothing_raised { @response = Verifone.perform!( :validate, @valid_card ) }
          assert_equal 'CARD OK ', @response.summary
        end

        should "successfully validate the card with card-swipe-data" do
          assert_nothing_raised { @response = Verifone.perform!( :validate, @valid_card_swipe ) }
          assert_equal 'CARD OK ', @response.summary
        end
      end

      context ":preauth -" do
        context "required options" do
          should "require amount" do
            assert_nothing_raised { Verifone.new( :preauth, @valid_card ) }
            @valid_card.delete :amount
            assert_raise( ArgumentError ) { Verifone.new( :preauth, @valid_card ) }
          end

          should "require payment info (either card or troutd)" do
            assert_raise( ArgumentError ) { Verifone.new(:preauth)}
            assert_nothing_raised { Verifone.new(:preauth, @valid_card ) }
            assert_nothing_raised { Verifone.new(:preauth, @valid_card_swipe ) }
            assert_nothing_raised { Verifone.new(:preauth, @static_troutd )}
          end
        end

        should "successfully preauth the card from card number" do
          assert_nothing_raised { @response = Verifone.perform!( :preauth, @valid_card ) }
          assert_match /^APPROVAL/, @response.summary
        end

        should "successfully preauth the card from card swipe" do
          assert_nothing_raised { @response = Verifone.perform!( :preauth, @valid_card_swipe ) }
          assert_match /^APPROVAL/, @response.summary
        end

        should "successfully preauth the card from troutd" do
          troutd = Verifone.perform!( :preauth, @valid_card.merge!(invoice:66669) ).troutd
          assert_nothing_raised { @response = Verifone.perform!( :preauth, @valid_troutd[troutd] ) }
          assert_match /^APPROVAL/, @response.summary
        end
      end

      context ":purchase -" do
        context "required options" do
          should "require amount" do
            assert_nothing_raised { Verifone.new( :purchase, @valid_card ) }
            @valid_card.delete :amount
            assert_raise(ArgumentError) { Verifone.new( :purchase, @valid_card ) }
          end

          should "require payment info (either card or troutd)" do
            assert_raise( ArgumentError ) { Verifone.new( :purchase )}
            assert_nothing_raised { Verifone.new(:purchase, @valid_card ) }
            assert_nothing_raised { Verifone.new(:purchase, @valid_card_swipe ) }
            assert_nothing_raised { Verifone.new(:purchase, @static_troutd ) }
          end
        end

        should "successfully process the purchase with card number" do
          assert_nothing_raised { @response = Verifone.perform!( :purchase, @valid_card ) }
          assert_match /^APPROVAL/, @response.summary
        end

        should "successfully process the purchase with card swipe" do
          assert_nothing_raised { @response = Verifone.perform!( :purchase, @valid_card_swipe ) }
          assert_match /^APPROVAL/, @response.summary
        end

        should "successfully process the purchase with troutd" do
          troutd = Verifone.perform!( :preauth, @valid_card.merge!(invoice:66669) ).troutd
          assert_nothing_raised { @response = Verifone.perform!( :purchase, @valid_troutd[troutd] ) }
          assert_match /^APPROVAL/, @response.summary
        end

        should "raise an exception when a duplicate transaction is placed" do
          assert_nothing_raised { Verifone.perform!( :purchase, @valid_card ) }
          verifone_obj = Verifone.new( :purchase, @valid_card )
          verifone_obj.request_xml= verifone_obj.request_xml << '  ' #adding whitespace to generate a new VCR call
          @response = verifone_obj.deliver!
          assert_match 'decline', @response.status
        end
      end

      context ":postauth -" do
        context "required options" do
          should "accepts but does not require amount" do
            assert_nothing_raised { Verifone.new( :postauth, @static_troutd ) }
            @static_troutd.delete :amount
            assert_nothing_raised { Verifone.new( :postauth, @static_troutd ) }
          end

          should "require troutd" do
            assert_raise( ArgumentError ) { Verifone.new( :postauth )}
            assert_raise( ArgumentError ) { Verifone.new( :postauth, @valid_card ) }
            assert_raise( ArgumentError ) { Verifone.new( :postauth, @valid_card_swipe ) }
            assert_nothing_raised { Verifone.new(:postauth, @static_troutd ) }
          end
        end

        # this applies to other actions, but involves a network call and does not depend on the action - so... called once
        should "require a valid troutd" do
          assert_raise(PaymentProcessing::InvalidTroutdError) { Verifone.perform!( :postauth, troutd: 'fake', amount: 100, invoice:54324 ) }
        end

        should "successfully process the full preauth" do
          troutd = Verifone.perform!( :preauth, @valid_card.merge!(invoice:11113) ).troutd
          assert_nothing_raised { @response = Verifone.perform!( :postauth, @valid_troutd[troutd]  ) }
          assert_equal 'CAPTURED', @response.summary
        end

        should "successfully process the a new amount" do
          troutd = Verifone.perform!( :preauth, @valid_card.merge!(invoice:22224) ).troutd
          assert_nothing_raised { @response = Verifone.perform!( :postauth, @valid_troutd[troutd]  ) }
          assert_match 'CAPTURED', @response.summary
        end
      end

      context ":refund" do
        context "required options" do
          should "require amount" do
            assert_nothing_raised { Verifone.new( :refund, @static_troutd ) }
            @static_troutd.delete :amount
            assert_raise( ArgumentError ) { Verifone.new( :refund, @static_troutd ) }
          end

          should "require a troutd" do
            assert_raise( ArgumentError ) { Verifone.new( :refund )}
            assert_raise( ArgumentError ) { Verifone.new(:refund, @valid_card ) }
            assert_raise( ArgumentError ) { Verifone.new(:refund, @valid_card_swipe ) }
            assert_nothing_raised { Verifone.new(:refund, @static_troutd ) }
          end
        end

        # POSSIBLE BUT CREDITING A NEW CARD COULD POTENTALLY VIOLATE NCAA REGULATIONS AROUND FINANCIAL AID
        # should "successfully process the full refund with the card number" do
        #   assert_nothing_raised { @response = Verifone.perform!( :refund, @valid_card ) }
        #   assert_equal 'CAPTURED', @response.summary
        # end

        # POSSIBLE BUT CREDITING A NEW CARD COULD POTENTALLY VIOLATE NCAA REGULATIONS AROUND FINANCIAL AID
        # should "successfully process the full refund with the card swipe data" do
        #   assert_nothing_raised { @response = Verifone.perform!( :refund, @valid_card_swipe ) }
        #   assert_equal 'CAPTURED', @response.summary
        # end

        should "successfully process the full refund with the troutd" do
          troutd = Verifone.perform!( :preauth, @valid_card.merge!(invoice:55556) ).troutd
          assert_nothing_raised { @response = Verifone.perform!( :refund, @valid_troutd[troutd] ) }
          assert_equal 'CAPTURED', @response.summary
        end

        should "successfully process a partial refund" do
          troutd = Verifone.perform!( :preauth, @valid_card.merge!(invoice:55556) ).troutd
          assert_nothing_raised { @response = Verifone.perform!( :refund, @valid_troutd[troutd].merge!( {amount:50} )) }
          assert_equal 'CAPTURED', @response.summary
        end
      end

      context ":void" do
        context "required options" do
          should "ignore amount" do
            assert_nothing_raised { Verifone.new( :void, @static_troutd ) }
            @static_troutd.delete :amount
            assert_nothing_raised { Verifone.new( :void, @static_troutd ) }
          end

          should "require troutd" do
            assert_raise( ArgumentError ) { Verifone.new( :void )}
            assert_raise( ArgumentError ) { Verifone.new(:void, @valid_card ) }
            assert_raise( ArgumentError ) { Verifone.new(:void, @valid_card_swipe ) }
            assert_nothing_raised { Verifone.new(:void, @static_troutd ) }
          end
        end

        should "successfully void the transaction" do
          troutd = Verifone.perform!( :preauth, @valid_card.merge!(invoice:33335) ).troutd
          assert_nothing_raised { @response = Verifone.perform!( :void, @valid_troutd[troutd] ) }
          assert_match /^APPROVAL/, @response.summary
        end
      end

      context "card declined" do
        setup do
          Curl::Easy.expects(:http_post).returns(mock(body_str:''))
          declined_hash = HashWithIndifferentAccess.new({ response:{ 'RESPONSE' => {
            'RESULT'      => 'DECLINED',
            'RESULT_CODE' => '93'
          }}})
          Verifone.any_instance.stubs(to_hash: declined_hash)
          @process_card = lambda { |options={}| Verifone.perform!( :purchase, @valid_card.merge(options) ) }
        end

        should "raise an exception" do
          assert_raise(PaymentProcessing::InvalidCreditCardError) { @process_card[] }
        end

        context "options[:skip_errors]" do
          should "not raise an error" do
            assert_nothing_raised { @process_card[ skip_errors:true ] }
          end

          should "#status should be 'decline'" do
            verifone_obj = @process_card[ skip_errors:true ]
            assert_equal 'decline', verifone_obj.status
          end
        end
      end
    end

    context ".valid_troutd?" do
      should "return TRUE for a valid troutd" do
        troutd = Verifone.perform!( :preauth, @valid_card.merge!(invoice:44447) ).troutd
        assert_true Verifone.valid_troutd?(troutd)
      end

      should "return FALSE for a valid troutd" do
        assert_false Verifone.valid_troutd?("123")
      end
    end

    context ".status" do
      should "be 'approved'" do
        charge = Verifone.perform!( :purchase, @valid_card )
        assert_equal 'approved', charge.status
      end
    end
  end
end