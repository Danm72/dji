require 'net/http'
require 'uri'
require 'json'

require 'nokogiri'         

module DJI
  class OrderTracking

    class << self

      # Retrieve an authenticity_token
      def authenticity_token(url)
        uri      = URI(url)
        http     = Net::HTTP.new uri.host, uri.port
        request  = Net::HTTP::Get.new uri.path
        response = http.request request
        
        page     = Nokogiri::HTML(response.body)
        token    = page.at_xpath('//meta[@name="csrf-token"]/@content').text    
        cookie   = response['set-cookie']

        { param: 'authenticity_token', token: token, cookie: cookie }
      end

      # Get the tracking details for an order
      def tracking_details(options = {})
        auth_token = authenticity_token(tracking_url)

        url = URI.parse(tracking_url)
        params = { 'number' => options[:order_number], 'phone_tail' => options[:phone_tail], 'utf8' => '✓' }
        params[auth_token[:param]] = auth_token[:token]

        headers = {
          'Content-Type' => 'application/x-www-form-urlencoded',
          'Cookie' => auth_token[:cookie],
          'Origin' => 'http://store.dji.com',
          'Referer' => tracking_url
        }

        http = Net::HTTP.new url.host, url.port
        request = Net::HTTP::Post.new url.path, headers
        request.set_form_data params
        res = http.request(request)

        data = case res
        when Net::HTTPSuccess, Net::HTTPRedirection
          # OK
          page = Nokogiri::HTML(res.body)
          content = page.at_xpath('//div[@id="main"]/div[@class="container"]/div[@class="row"]/div[@class="col-xs-9"]/div[@class="col-xs-10 well"][2]')
          # puts content
          data = {}
          data[:order_number] = content.at_xpath('div[1]').text.split(' ')[-1]
          data[:total]        = content.at_xpath('div[2]').text.split(' ')[1..-1].join(' ')
          data[:payment_status] = content.at_xpath('div[3]').text.split(': ')[1]
          data[:shipping_status] = content.at_xpath('div[4]').text.split(': ')[1]
          data[:shipping_company] = content.at_xpath('div[5]/span').text
          data[:tracking_number] = content.at_xpath('div[6]/a').text

          data[:dji_username] = options[:dji_username] if options[:dji_username].present?
          
          print_tracking_details(data)
          data
        else
          puts "There was an error: #{res.message}"
          nil
        end
        
        data
      end

      # The URL for order tracking
      def tracking_url
        'http://store.dji.com/orders/tracking'
      end

      def print_tracking_details(data)
          now = Time.now.to_s

          puts
          puts "ORDER TRACKING AS OF #{now}"
          puts "------------------------------------------------------"
          puts "DJI Forum Username : #{data[:dji_username]}" if data[:dji_username]
          puts "Order Number       : #{data[:order_number]}"
          puts "Total              : #{data[:total]}"
          puts "Payment Status     : #{data[:payment_status]}"
          puts "Shipping Status    : #{data[:shipping_status]}"
          puts "Shipping Company   : #{data[:shipping_company]}"
          puts "Tracking Number    : #{data[:tracking_number]}"
          puts
      end

      def publish(data)
        url = URI.parse(publish_url)
        params = {
          format:           :json,
          order: {
            order_id:     data[:order_number],
            payment_status:   data[:payment_status],
            payment_total:    data[:total],
            shipping_status:  data[:shipping_status],
            shipping_company: data[:shipping_company],
            tracking_number:  data[:tracking_number],
            dji_username:     data[:dji_username]
          }
        }

        headers = {
          'Accepts' => 'application/json',
          'Content-Type' => 'application/json'
        }

        http = Net::HTTP.new url.host, url.port
        request = Net::HTTP::Post.new url.path, headers
        request.body = params.to_json
        res = http.request(request)

        case res
        when Net::HTTPSuccess, Net::HTTPRedirection
          puts "You have successfully published your latest order status."
          puts "See order statuses reported by others at #{publish_url}"
        else
          puts "There was an error trying to publish your order status: #{res.message}"
        end
        
      end

      def publish_url
        'http://localhost:3000/orders'
        #'http://dji-track.herokuapp.com/orders'
      end

    end
    
  end
end