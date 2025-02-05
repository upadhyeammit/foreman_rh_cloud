require 'rest-client'

module InventorySync
  module Async
    class QueryInventoryJob < ::Actions::EntryAction
      include ActiveSupport::Callbacks
      include ::ForemanRhCloud::CloudAuth

      define_callbacks :iteration, :step

      def run
        run_callbacks :iteration do
          page = 1
          loop do
            api_response = query_inventory(page)
            results = HostResult.new(api_response)
            logger.debug("Downloaded cloud inventory data: #{results.percentage}%")

            run_callbacks :step do
              results
            end

            page += 1
            break if results.last?
          end
        end
      end

      private

      def query_inventory(page = 1)
        hosts_inventory_response = RestClient::Request.execute(
          method: :get,
          url: ForemanInventoryUpload.inventory_export_url,
          verify_ssl: ForemanRhCloud.verify_ssl_method,
          proxy: ForemanRhCloud.transformed_http_proxy_string(logger: logger),
          headers: {
            Authorization: "Bearer #{rh_credentials}",
            params: {
              per_page: 100,
              page: page,
            },
          }
        )

        JSON.parse(hosts_inventory_response)
      end

      def logger
        action_logger
      end
    end
  end
end
