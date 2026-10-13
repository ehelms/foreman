module Api
  module V2
    class InfrastructureHostsController < V2::BaseController
      before_action :require_admin, only: [:index, :show]
      before_action :reject_unsupported_filters, only: :index
      hide_taxonomy_options

      api :GET, '/infrastructure_hosts', N_('Admin-only list of Foreman and Capsule hosts')
      param_group :pagination, ::Api::V2::BaseController
      returns desc: N_('Paginated list of infrastructure hosts') do
        property :total, Integer
        property :subtotal, Integer
        property :page, Integer
        property :per_page, Integer, desc: N_('For per_page=all, this is the total number of hosts')
        property :results, Array, desc: N_('Infrastructure hosts with their registered Smart Proxies')
      end
      def index
        @infrastructure_hosts = InfrastructureHostPresenter.all
        @total = @infrastructure_hosts.size
        @per_page = metadata_per_page
        @page = metadata_page
        unless params[:per_page] == 'all'
          @infrastructure_hosts = @infrastructure_hosts.paginate(page: @page, per_page: @per_page)
        end
      end

      api :GET, '/infrastructure_hosts/:id', N_('Show an admin-only Foreman or Capsule host; returns 404 when the hostname is unknown')
      param :id, :identifier_dottable, :required => true, :desc => N_('Hostname of the infrastructure host')
      returns desc: N_('Infrastructure host and its registered Smart Proxies') do
        property :id, String, desc: N_('Normalized hostname used as the stable identifier')
        property :hostname, String
        property :kind, ['foreman', 'capsule']
        property :smart_proxies_count, Integer
        property :smart_proxies, Array
      end
      def show
        @infrastructure_host = InfrastructureHostPresenter.find(params[:id])
        return not_found unless @infrastructure_host
      end

      private

      def index_node_permissions
        { can_create: false, can_edit: false }
      end

      def reject_unsupported_filters
        unsupported = [:search, :order].select { |key| params.key?(key) }
        return if unsupported.empty?

        render json: { message: _('Search and ordering are not supported for the infrastructure host inventory') },
          status: :bad_request
      end
    end
  end
end
