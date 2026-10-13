require 'test_helper'

class InfrastructureHostsControllerTest < ActionController::TestCase
  test 'denies direct HTML list and detail routes to non-admins' do
    setup_user 'view', 'hosts'
    InfrastructureHostPresenter.expects(:all).never
    InfrastructureHostPresenter.expects(:find).never

    get :index
    assert_response :forbidden

    get :index, params: { id: 'capsule.example.com' }
    assert_response :forbidden
  end
end
