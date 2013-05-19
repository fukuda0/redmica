# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../../test_helper', __FILE__)

class IssuesHelperTest < ActionView::TestCase
  include ApplicationHelper
  include Redmine::I18n
  include IssuesHelper
  include CustomFieldsHelper
  include ERB::Util

  fixtures :projects, :trackers, :issue_statuses, :issues,
           :enumerations, :users, :issue_categories,
           :projects_trackers,
           :roles,
           :member_roles,
           :members,
           :enabled_modules,
           :custom_fields,
           :attachments,
           :versions

  def setup
    super
    set_language_if_valid('en')
    User.current = nil
  end

  def test_issue_heading
    assert_equal "Bug #1", issue_heading(Issue.find(1))
  end

  def test_issues_destroy_confirmation_message_with_one_root_issue
    assert_equal l(:text_issues_destroy_confirmation),
                 issues_destroy_confirmation_message(Issue.find(1))
  end

  def test_issues_destroy_confirmation_message_with_an_arrayt_of_root_issues
    assert_equal l(:text_issues_destroy_confirmation),
                 issues_destroy_confirmation_message(Issue.find([1, 2]))
  end

  def test_issues_destroy_confirmation_message_with_one_parent_issue
    Issue.find(2).update_attribute :parent_issue_id, 1
    assert_equal l(:text_issues_destroy_confirmation) + "\n" +
                   l(:text_issues_destroy_descendants_confirmation, :count => 1),
                 issues_destroy_confirmation_message(Issue.find(1))
  end

  def test_issues_destroy_confirmation_message_with_one_parent_issue_and_its_child
    Issue.find(2).update_attribute :parent_issue_id, 1
    assert_equal l(:text_issues_destroy_confirmation),
                 issues_destroy_confirmation_message(Issue.find([1, 2]))
  end

  test 'show_detail with no_html should show a changing attribute' do
    detail = JournalDetail.new(:property => 'attr', :old_value => '40',
                               :value => '100', :prop_key => 'done_ratio')
    assert_equal "% Done changed from 40 to 100", show_detail(detail, true)
  end

  test 'show_detail with no_html should show a new attribute' do
    detail = JournalDetail.new(:property => 'attr', :old_value => nil,
                               :value => '100', :prop_key => 'done_ratio')
    assert_equal "% Done set to 100", show_detail(detail, true)
  end

  test 'show_detail with no_html should show a deleted attribute' do
    detail = JournalDetail.new(:property => 'attr', :old_value => '50',
                               :value => nil, :prop_key => 'done_ratio')
    assert_equal "% Done deleted (50)", show_detail(detail, true)
  end

  test 'show_detail with html should show a changing attribute with HTML highlights' do
    detail = JournalDetail.new(:property => 'attr', :old_value => '40',
                               :value => '100', :prop_key => 'done_ratio')
    html = show_detail(detail, false)
    assert_include '<strong>% Done</strong>', html
    assert_include '<i>40</i>', html
    assert_include '<i>100</i>', html
  end

  test 'show_detail with html should show a new attribute with HTML highlights' do
    detail = JournalDetail.new(:property => 'attr', :old_value => nil,
                               :value => '100', :prop_key => 'done_ratio')
    html = show_detail(detail, false)
    assert_include '<strong>% Done</strong>', html
    assert_include '<i>100</i>', html
  end

  test 'show_detail with html should show a deleted attribute with HTML highlights' do
    detail = JournalDetail.new(:property => 'attr', :old_value => '50',
                               :value => nil, :prop_key => 'done_ratio')
    html = show_detail(detail, false)
    assert_include '<strong>% Done</strong>', html
    assert_include '<del><i>50</i></del>', html
  end

  test 'show_detail with a start_date attribute should format the dates' do
    detail = JournalDetail.new(
               :property  => 'attr',
               :old_value => '2010-01-01',
               :value     => '2010-01-31',
               :prop_key  => 'start_date'
            )
    with_settings :date_format => '%m/%d/%Y' do
      assert_match "01/31/2010", show_detail(detail, true)
      assert_match "01/01/2010", show_detail(detail, true)
    end
  end

  test 'show_detail with a due_date attribute should format the dates' do
    detail = JournalDetail.new(
              :property  => 'attr',
              :old_value => '2010-01-01',
              :value     => '2010-01-31',
              :prop_key  => 'due_date'
            )
    with_settings :date_format => '%m/%d/%Y' do
      assert_match "01/31/2010", show_detail(detail, true)
      assert_match "01/01/2010", show_detail(detail, true)
    end
  end

  test 'show_detail should show old and new values with a project attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'project_id',
                               :old_value => 1, :value => 2)
    assert_match 'eCookbook', show_detail(detail, true)
    assert_match 'OnlineStore', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a issue status attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'status_id',
                               :old_value => 1, :value => 2)
    assert_match 'New', show_detail(detail, true)
    assert_match 'Assigned', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a tracker attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'tracker_id',
                               :old_value => 1, :value => 2)
    assert_match 'Bug', show_detail(detail, true)
    assert_match 'Feature request', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a assigned to attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'assigned_to_id',
                               :old_value => 1, :value => 2)
    assert_match 'Redmine Admin', show_detail(detail, true)
    assert_match 'John Smith', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a priority attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'priority_id',
                               :old_value => 4, :value => 5)
    assert_match 'Low', show_detail(detail, true)
    assert_match 'Normal', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a category attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'category_id',
                               :old_value => 1, :value => 2)
    assert_match 'Printing', show_detail(detail, true)
    assert_match 'Recipes', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a fixed version attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'fixed_version_id',
                               :old_value => 1, :value => 2)
    assert_match '0.1', show_detail(detail, true)
    assert_match '1.0', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a estimated hours attribute' do
    detail = JournalDetail.new(:property => 'attr', :prop_key => 'estimated_hours',
                               :old_value => '5', :value => '6.3')
    assert_match '5.00', show_detail(detail, true)
    assert_match '6.30', show_detail(detail, true)
  end

  test 'show_detail should show old and new values with a custom field' do
    detail = JournalDetail.new(:property => 'cf', :prop_key => '1',
                               :old_value => 'MySQL', :value => 'PostgreSQL')
    assert_equal 'Database changed from MySQL to PostgreSQL', show_detail(detail, true)
  end

  test 'show_detail should show added file' do
    detail = JournalDetail.new(:property => 'attachment', :prop_key => '1',
                               :old_value => nil, :value => 'error281.txt')
    assert_match 'error281.txt', show_detail(detail, true)
  end

  test 'show_detail should show removed file' do
    detail = JournalDetail.new(:property => 'attachment', :prop_key => '1',
                               :old_value => 'error281.txt', :value => nil)
    assert_match 'error281.txt', show_detail(detail, true)
  end

  def test_show_detail_create_relation
    detail = JournalDetail.new(:property => 'relation',
                               :prop_key => 'label_precedes',
                               :value    => 1)
    assert_equal "Precedes Bug #1: Can't print recipes added", show_detail(detail, true)
    assert_match %r{<strong>Precedes</strong> <i><a href="/issues/1" class=".+">Bug #1</a>: Can&#x27;t print recipes</i> added},
                 show_detail(detail, false)
    non_existed_issue_number = 9999
    assert_nil  Issue.find_by_id(non_existed_issue_number)
    detail = JournalDetail.new(:property => 'relation',
                               :prop_key => 'label_precedes',
                               :value    => non_existed_issue_number)
    assert_equal "Precedes Issue #{non_existed_issue_number} added", show_detail(detail, true)
    assert_equal "<strong>Precedes</strong> <i>Issue #{non_existed_issue_number}</i> added", show_detail(detail, false)
  end

  def test_show_detail_delete_relation
    detail = JournalDetail.new(:property  => 'relation',
                               :prop_key  => 'label_precedes',
                               :old_value => 1)
    assert_equal "Precedes deleted (Bug #1: Can't print recipes)", show_detail(detail, true)
    assert_match %r{<strong>Precedes</strong> deleted \(<del><i><a href="/issues/1" class=".+">Bug #1</a>: Can&#x27;t print recipes</i></del>\)},
                 show_detail(detail, false)
    non_existed_issue_number = 9999
    assert_nil  Issue.find_by_id(non_existed_issue_number)
    detail = JournalDetail.new(:property  => 'relation',
                               :prop_key  => 'label_precedes',
                               :old_value => non_existed_issue_number)
    assert_equal "Precedes deleted (Issue 9999)", show_detail(detail, true)
    assert_equal "<strong>Precedes</strong> deleted (<del><i>Issue 9999</i></del>)", show_detail(detail, false)
  end
end
