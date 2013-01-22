require File.expand_path('../../../test_helper', __FILE__)

class Redmine::ApiTest::HttpBasicLoginTest < Redmine::ApiTest::Base
  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :workflows

  def setup
    Setting.rest_api_enabled = '1'
    Setting.login_required = '1'
  end

  def teardown
    Setting.rest_api_enabled = '0'
    Setting.login_required = '0'
  end

  # Using the NewsController because it's a simple API.
  context "get /news" do
    setup do
      project = Project.find('onlinestore')
      EnabledModule.create(:project => project, :name => 'news')
    end

    context "in :xml format" do
      should_allow_http_basic_auth_with_username_and_password(:get, "/projects/onlinestore/news.xml")
    end

    context "in :json format" do
      should_allow_http_basic_auth_with_username_and_password(:get, "/projects/onlinestore/news.json")
    end
  end
end
