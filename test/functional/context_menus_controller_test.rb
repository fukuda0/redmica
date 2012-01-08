require File.expand_path('../../test_helper', __FILE__)

class ContextMenusControllerTest < ActionController::TestCase
  fixtures :projects,
           :trackers,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :auth_sources,
           :enabled_modules,
           :workflows,
           :journals, :journal_details,
           :versions,
           :issues, :issue_statuses, :issue_categories,
           :users,
           :enumerations,
           :time_entries

  def test_context_menu_one_issue
    @request.session[:user_id] = 2
    get :issues, :ids => [1]
    assert_response :success
    assert_template 'context_menu'
    assert_tag :tag => 'a', :content => 'Edit',
                            :attributes => { :href => '/issues/1/edit',
                                             :class => 'icon-edit' }
    assert_tag :tag => 'a', :content => 'Closed',
                            :attributes => { :href => '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bstatus_id%5D=5',
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Immediate',
                            :attributes => { :href => '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bpriority_id%5D=8',
                                             :class => '' }
    assert_no_tag :tag => 'a', :content => 'Inactive Priority'
    # Versions
    assert_tag :tag => 'a', :content => '2.0',
                            :attributes => { :href => '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bfixed_version_id%5D=3',
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'eCookbook Subproject 1 - 2.0',
                            :attributes => { :href => '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bfixed_version_id%5D=4',
                                             :class => '' }

    assert_tag :tag => 'a', :content => 'Dave Lopper',
                            :attributes => { :href => '/issues/bulk_update?ids%5B%5D=1&amp;issue%5Bassigned_to_id%5D=3',
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Copy',
                            :attributes => { :href => '/projects/ecookbook/issues/1/copy',
                                             :class => 'icon-copy' }
    assert_no_tag :tag => 'a', :content => 'Move'
    assert_tag :tag => 'a', :content => 'Delete',
                            :attributes => { :href => '/issues?ids%5B%5D=1',
                                             :class => 'icon-del' }
  end

  def test_context_menu_one_issue_by_anonymous
    get :issues, :ids => [1]
    assert_response :success
    assert_template 'context_menu'
    assert_tag :tag => 'a', :content => 'Delete',
                            :attributes => { :href => '#',
                                             :class => 'icon-del disabled' }
  end

  def test_context_menu_multiple_issues_of_same_project
    @request.session[:user_id] = 2
    get :issues, :ids => [1, 2]
    assert_response :success
    assert_template 'context_menu'
    assert_not_nil assigns(:issues)
    assert_equal [1, 2], assigns(:issues).map(&:id).sort

    ids = assigns(:issues).map(&:id).map {|i| "ids%5B%5D=#{i}"}.join('&amp;')
    assert_tag :tag => 'a', :content => 'Edit',
                            :attributes => { :href => "/issues/bulk_edit?#{ids}",
                                             :class => 'icon-edit' }
    assert_tag :tag => 'a', :content => 'Closed',
                            :attributes => { :href => "/issues/bulk_update?#{ids}&amp;issue%5Bstatus_id%5D=5",
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Immediate',
                            :attributes => { :href => "/issues/bulk_update?#{ids}&amp;issue%5Bpriority_id%5D=8",
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Dave Lopper',
                            :attributes => { :href => "/issues/bulk_update?#{ids}&amp;issue%5Bassigned_to_id%5D=3",
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Copy',
                            :attributes => { :href => "/issues/bulk_edit?copy=1&amp;#{ids}",
                                             :class => 'icon-copy' }
    assert_no_tag :tag => 'a', :content => 'Move'
    assert_tag :tag => 'a', :content => 'Delete',
                            :attributes => { :href => "/issues?#{ids}",
                                             :class => 'icon-del' }
  end

  def test_context_menu_multiple_issues_of_different_projects
    @request.session[:user_id] = 2
    get :issues, :ids => [1, 2, 6]
    assert_response :success
    assert_template 'context_menu'
    assert_not_nil assigns(:issues)
    assert_equal [1, 2, 6], assigns(:issues).map(&:id).sort

    ids = assigns(:issues).map(&:id).map {|i| "ids%5B%5D=#{i}"}.join('&amp;')
    assert_tag :tag => 'a', :content => 'Edit',
                            :attributes => { :href => "/issues/bulk_edit?#{ids}",
                                             :class => 'icon-edit' }
    assert_tag :tag => 'a', :content => 'Closed',
                            :attributes => { :href => "/issues/bulk_update?#{ids}&amp;issue%5Bstatus_id%5D=5",
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Immediate',
                            :attributes => { :href => "/issues/bulk_update?#{ids}&amp;issue%5Bpriority_id%5D=8",
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'John Smith',
                            :attributes => { :href => "/issues/bulk_update?#{ids}&amp;issue%5Bassigned_to_id%5D=2",
                                             :class => '' }
    assert_tag :tag => 'a', :content => 'Delete',
                            :attributes => { :href => "/issues?#{ids}",
                                             :class => 'icon-del' }
  end

  def test_context_menu_issue_visibility
    get :issues, :ids => [1, 4]
    assert_response :success
    assert_template 'context_menu'
    assert_equal [1], assigns(:issues).collect(&:id)
  end
  
  def test_time_entries_context_menu
    @request.session[:user_id] = 2
    get :time_entries, :ids => [1, 2]
    assert_response :success
    assert_template 'time_entries'
    assert_tag 'a', :content => 'Edit'
    assert_no_tag 'a', :content => 'Edit', :attributes => {:class => /disabled/}
  end
  
  def test_time_entries_context_menu_without_edit_permission
    @request.session[:user_id] = 2
    Role.find_by_name('Manager').remove_permission! :edit_time_entries
    
    get :time_entries, :ids => [1, 2]
    assert_response :success
    assert_template 'time_entries'
    assert_tag 'a', :content => 'Edit', :attributes => {:class => /disabled/}
  end
end
