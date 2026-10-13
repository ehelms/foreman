object @infrastructure_host

attributes :id, :hostname, :kind, :smart_proxies_count

child :smart_proxies do
  attributes :id, :name, :url
end
