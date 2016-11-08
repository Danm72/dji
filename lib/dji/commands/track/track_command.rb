require 'time'

module DJI
  module Command
    class TrackCommand < Base
      desc 'track ORDER_NUMBER PHONE_TAIL', 'track an order'
      option :order_number, required: true, aliases: :o
      option :phone_tail, required: true, aliases: :p

      option :repeat, required: false, aliases: :r
      option :publish, required: false, default: false

      option :country, required: false, aliases: :c
      option :debug, required: false, default: false, aliases: :d
      option :dji_username, required: false, aliases: [:username, :u]
      option :email_address, required: false, aliases: [:email, :e]
      option :order_time, required: false, aliases: :t

      def track
        order_time = Time.parse(options[:order_time]) if options[:order_time].present?

        provided_options = {
          order_number:  options[:order_number],
          order_time:    order_time,
          phone_tail:    options[:phone_tail],
          country:       options[:country],
          debug:         options[:debug],
          dji_username:  options[:dji_username],
          email_address: options[:email_address],
          debug:         options[:debug],
          output:        true
        }

        if options[:repeat].present?
          interval = options[:repeat].to_i.presence || 300
          puts
          puts "Requesting order tracking details every #{interval} seconds. Press CONTROL-C to stop..."

          while true
            data = DJI::OrderTracking.tracking_details(provided_options)
            DJI::OrderTracking.publish(data) if data.present? && options[:publish].present?
            sleep(interval)
          end
        else
          data = DJI::OrderTracking.tracking_details(provided_options)
          DJI::OrderTracking.publish(data) if data.present? && options[:publish].present?
        end
      end
    end
  end
end
