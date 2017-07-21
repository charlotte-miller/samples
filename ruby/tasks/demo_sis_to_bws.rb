require 'rubygems'
require 'active_support/core_ext/hash'

# CONFIG AND SETUP
puts "Getting Ready to Test BWS"
DOMAIN  = 'bws.cloud-credit.stg.bookrenter.com'
API_KEY = 'zFdQnOFMknkZMmudgkWZ'
ISBN    = '9780073530680'


# A few helper methods to DRY the rest of the demo
# Makes this possible: `request_uri.send_to_bws(request_body)`
class Hash
  def to_bws_xml
    {body:self}.to_xml(root:'envelope', skip_instruct:false, dasherize:false, skip_types:true)
  end

  def send_to_bws!(request_body=nil)
    request_body = "-d '#{request_body.to_bws_xml}'" if request_body
    output = `curl -k #{request_body} -H 'Content-Type: text/xml' -X #{keys.first.to_s.upcase} 'https://#{DOMAIN}#{values.first}?api_key=#{API_KEY}'`
    puts output
  end
end


#############################################
# WELCOME - START HERE!

# STEP 1
puts "Getting Book Information"
request_uri = {get: "/v1/inventory_books/#{ISBN}.xml"}
request_uri.send_to_bws!

# STEP 2
puts "Placing Order"
request_uri  = {post: '/v1/checkout/single_post_create_order.xml'}
request_body = {
  checkout_single_post_create_order:{
    charge_amount_cents: '6724',
    external_order_id: "CLOUD-STORE-ORDER-#{Time.now.to_i}",
    customer:{
      email: 'dorothea@toydurgan.us',
      external_user_id:'6370931058',
      phone: '1234567890',
    },
    product_list:{
      subtotal_cents:'6221',
      subtotal_tax_cents:'495',  #TX tax 0.07949
      products:{
        product:{
          product_id: ISBN,
          product_type:'book',
          quantity:'1',
          rental_period:'125',
          external_line_item_id:'CLOUD-STORE-LINE-ITEM-123003',
          price_cents:'6221',
          retail_price_cents: '23200',
        },
      },
    },
    billing_address: {
      first_name:'Rhiannon',
      last_name:'Okuneva',
      street_address:'31189 ZackRapid',
      street_address_2:'',
      city:'Lake Jedediah',
      state:'TX',
      zip:'83492-3353',
      country:'USA',
    },
    shipping_address:{
      first_name:'Rhiannon',
      last_name:'Okuneva',
      street_address:'31189 ZackRapid',
      street_address_2:'',
      city:'Lake Jedediah',
      state:'TX',
      zip:'83492-3353',
      country:'USA',
    },
    shipping_option:{
      method_name:'Ground',
      shipping_price_cents:'100',
      tax_cost_cents:'8',
    }
  }
}
request_uri.send_to_bws!(request_body)

# STEP 3
puts "Refunding Order"
request_uri  = {post: '/v1/refunds.xml'}
request_body = {
  refunds_create:{
    refund:{
      order_id:'BR-62778BD22',    # these come from the Order creation
      line_item_id:'LI_4598392',  # these come from the Order creation
      refund_amount_cents:'6724',
      reason:'Student dropped the course',
    }
  }
}
request_uri.send_to_bws!(request_body)