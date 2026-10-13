# A global, read-only view of the machines running Foreman and registered Smart Proxies.
# These machines need not be managed Hosts (and therefore need no taxonomy).
class InfrastructureHostPresenter
  attr_reader :hostname, :kind, :smart_proxies

  def self.all
    # Prefer Foreman's configured FQDN; only fall back to foreman_url when it is
    # unavailable, since that URL may point to a load balancer in multi-node setups.
    foreman_hostname = normalize_hostname(SETTINGS[:fqdn]) || hostname_from_url(Setting[:foreman_url])
    hosts = {}
    hosts[foreman_hostname] = new(foreman_hostname, 'foreman') if foreman_hostname.present?

    # SmartProxy's default scope limits results to the selected organization and
    # location. Infrastructure is global, so intentionally bypass that scope.
    SmartProxy.unscoped.select(:id, :name, :url).find_each do |proxy|
      hostname = hostname_from_url(proxy.url)
      next unless hostname

      hosts[hostname] ||= new(hostname, 'capsule')
      hosts[hostname].smart_proxies << proxy
    end

    hosts.each_value { |host| host.smart_proxies.sort_by! { |proxy| [proxy.name.downcase, proxy.id] } }
    hosts.values.sort_by { |host| [host.kind == 'foreman' ? 0 : 1, host.hostname] }
  end

  def self.find(hostname)
    all.find { |host| host.hostname == normalize_hostname(hostname) }
  end

  def self.normalize_hostname(hostname)
    hostname&.strip&.downcase&.delete_suffix('.')&.presence
  end

  def self.hostname_from_url(url)
    normalize_hostname(URI.parse(url).hostname)
  rescue URI::Error, ArgumentError, TypeError
    nil
  end

  def initialize(hostname, kind)
    @hostname = hostname
    @kind = kind
    @smart_proxies = []
  end

  alias_method :id, :hostname

  def smart_proxies_count
    smart_proxies.size
  end
end
