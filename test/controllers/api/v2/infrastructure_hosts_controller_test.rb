require 'test_helper'

class Api::V2::InfrastructureHostsControllerTest < ActionController::TestCase
  test 'lists the Foreman FQDN even when no smart proxy runs on it' do
    with_temporary_settings(fqdn: 'foreman-host.example.com') do
      get :index
      assert_response :ok

      data = JSON.parse(response.body)
      foreman = data['results'].first
      assert_equal 'foreman-host.example.com', foreman['id']
      assert_equal 'foreman', foreman['kind']
      assert_equal 0, foreman['smart_proxies_count']
      assert_empty foreman['smart_proxies']
      assert_equal data['results'].size, data['total']
      assert_equal false, data['can_create'] if data.key?('can_create')
    end
  end

  test 'uses SETTINGS fqdn instead of the load-balanced Foreman URL' do
    with_foreman_url('https://foreman-lb.example.com') do
      with_temporary_settings(fqdn: 'foreman-node.example.com') do
        get :index
        assert_response :ok

        hostnames = JSON.parse(response.body)['results'].map { |host| host['hostname'] }
        assert_includes hostnames, 'foreman-node.example.com'
        refute_includes hostnames, 'foreman-lb.example.com'
      end
    end
  end

  test 'falls back to the configured Foreman URL when the FQDN is unavailable' do
    with_foreman_url('https://foreman-fallback.example.com:8443') do
      with_temporary_settings(fqdn: nil) do
        get :index
        assert_response :ok

        foreman = JSON.parse(response.body)['results'].first
        assert_equal 'foreman-fallback.example.com', foreman['hostname']
        assert_equal 'foreman', foreman['kind']
      end
    end
  end

  test 'groups all co-located smart proxies on Foreman by normalized URL hostname' do
    with_temporary_settings(fqdn: 'FOREMAN.EXAMPLE.COM.') do
      smart_proxies(:one).update_column(:url, 'https://Foreman.Example.Com.:8443')
      smart_proxies(:two).update_column(:url, 'http://foreman.example.com:9090')

      get :show, params: { id: 'FOREMAN.example.com.' }
      assert_response :ok

      data = JSON.parse(response.body)
      assert_equal 'foreman.example.com', data['hostname']
      assert_equal 'foreman', data['kind']
      assert_equal 2, data['smart_proxies_count']
      assert_equal [smart_proxies(:one).id, smart_proxies(:two).id].sort,
        data['smart_proxies'].map { |proxy| proxy['id'] }.sort
      assert data['smart_proxies'].all? { |proxy| proxy.key?('name') && proxy.key?('url') }
    end
  end

  test 'groups proxies on the same Capsule and uses the URL rather than the proxy name' do
    get :show, params: { id: 'else.where' }
    assert_response :ok

    data = JSON.parse(response.body)
    assert_equal 'capsule', data['kind']
    assert_equal 'else.where', data['hostname']
    assert_equal data['smart_proxies'].size, data['smart_proxies_count']
    assert_includes data['smart_proxies'].map { |proxy| proxy['id'] }, smart_proxies(:three).id
    assert_includes data['smart_proxies'].map { |proxy| proxy['id'] }, smart_proxies(:puppetmaster).id
    refute_includes data['smart_proxies'].map { |proxy| proxy['id'] }, smart_proxies(:one).id
  end

  test 'skips malformed or empty proxy URLs without failing the inventory' do
    smart_proxies(:one).update_column(:url, '://malformed url')
    smart_proxies(:two).update_column(:url, '')

    get :index
    assert_response :ok

    data = JSON.parse(response.body)
    assert_equal data['total'], data['results'].size
    refute_includes data['results'].map { |host| host['hostname'] }, 'somewhere.net'
    refute_includes data['results'].map { |host| host['hostname'] }, ''
  end

  test 'groups IPv6 proxy URLs by their hostname' do
    smart_proxies(:one).update_column(:url, 'https://[2001:db8::1]:8443')

    get :show, params: { id: '2001:db8::1' }
    assert_response :ok

    data = JSON.parse(response.body)
    assert_equal '2001:db8::1', data['hostname']
    assert_equal 'capsule', data['kind']
    assert_equal [smart_proxies(:one).id], data['smart_proxies'].map { |proxy| proxy['id'] }
  end

  test 'lists all infrastructure hosts regardless of selected taxonomies' do
    in_taxonomy(:organization2) do
      in_taxonomy(:location2) do
        refute SmartProxy.where(id: smart_proxies(:one).id).exists?

        get :show, params: { id: 'somewhere.net' }
        assert_response :ok
        assert_equal smart_proxies(:one).id, JSON.parse(response.body)['smart_proxies'].first['id']
      end
    end
  end

  test 'supports pagination of the host list after grouping' do
    get :index, params: { page: 2, per_page: 1, include_permissions: true }
    assert_response :ok

    data = JSON.parse(response.body)
    assert_equal 2, data['page']
    assert_equal 1, data['per_page']
    assert_equal 1, data['results'].size
    assert_operator data['total'], :>, 1
    assert_equal data['total'], data['subtotal']
    assert_equal false, data['can_create']
    assert_equal false, data['can_edit']
  end

  test 'supports per_page all' do
    get :index, params: { per_page: 'all' }
    assert_response :ok

    data = JSON.parse(response.body)
    assert_equal data['total'], data['subtotal']
    assert_equal data['total'], data['per_page']
    assert_equal data['total'], data['results'].size
  end

  test 'rejects unsupported search and order parameters' do
    get :index, params: { search: 'kind = foreman' }
    assert_response :bad_request
    assert_match(/Search and ordering are not supported/, response.body)

    get :index, params: { order: 'hostname DESC' }
    assert_response :bad_request
  end

  test 'returns 404 for an unknown hostname' do
    get :show, params: { id: 'missing.example.com' }
    assert_response :not_found
  end

  test 'routes dotted hostnames and URL-encoded IPv6 hostnames to show' do
    dotted_route = Rails.application.routes.recognize_path(
      '/api/v2/infrastructure_hosts/foreman.example.com', method: :get
    )
    ipv6_route = Rails.application.routes.recognize_path(
      '/api/v2/infrastructure_hosts/2001%3Adb8%3A%3A1', method: :get
    )

    assert_equal 'show', dotted_route[:action]
    assert_equal 'foreman.example.com', dotted_route[:id]
    assert_equal 'show', ipv6_route[:action]
    assert_equal '2001:db8::1', ipv6_route[:id]
  end

  test 'requires an administrator even when granted host or proxy view permissions' do
    InfrastructureHostPresenter.expects(:all).never
    InfrastructureHostPresenter.expects(:find).never

    ['hosts', 'smart_proxies'].each do |resource|
      setup_user 'view', resource

      get :index
      assert_response :forbidden
      get :show, params: { id: 'somewhere.net' }
      assert_response :forbidden
    end
  end

  private

  def with_foreman_url(url)
    original_url = Setting[:foreman_url]
    Setting[:foreman_url] = url
    yield
  ensure
    Setting[:foreman_url] = original_url
  end
end
