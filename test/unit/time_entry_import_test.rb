require File.expand_path('../../test_helper', __FILE__)

class TimeEntryImportTest < ActiveSupport::TestCase
  fixtures :projects, :enabled_modules,
           :users, :email_addresses,
           :roles, :members, :member_roles,
           :issues, :issue_statuses,
           :trackers, :projects_trackers,
           :versions,
           :issue_categories,
           :enumerations,
           :workflows,
           :custom_fields,
           :custom_values

  include Redmine::I18n

  def setup
    set_language_if_valid 'en'
  end

  def test_authorized
    assert  TimeEntryImport.authorized?(User.find(1)) # admins
    assert  TimeEntryImport.authorized?(User.find(2)) # has log_time permission
    assert !TimeEntryImport.authorized?(User.find(6)) # anonymous does not have log_time permission
  end

  def test_maps_issue_id
    import = generate_import_with_mapping
    first, second, third, fourth = new_records(TimeEntry, 4) { import.run }

    assert_nil first.issue_id
    assert_nil second.issue_id
    assert_equal 1, third.issue_id
    assert_equal 2, fourth.issue_id
  end

  def test_maps_date
    import = generate_import_with_mapping
    first, second, third, fourth = new_records(TimeEntry, 4) { import.run }

    assert_equal Date.new(2020, 1, 1), first.spent_on
    assert_equal Date.new(2020, 1, 2), second.spent_on
    assert_equal Date.new(2020, 1, 3), third.spent_on
    assert_equal Date.new(2020, 1, 4), fourth.spent_on
  end

  def test_maps_hours
    import = generate_import_with_mapping
    first, second, third, fourth = new_records(TimeEntry, 4) { import.run }

    assert_equal 1, first.hours
    assert_equal 2, second.hours
    assert_equal 3, third.hours
    assert_equal 4, fourth.hours
  end

  def test_maps_comments
    import = generate_import_with_mapping
    first, second, third, fourth = new_records(TimeEntry, 4) { import.run }

    assert_equal 'Some Design',      first.comments
    assert_equal 'Some Development', second.comments
    assert_equal 'Some QA',          third.comments
    assert_equal 'Some Inactivity',  fourth.comments
  end

  def test_maps_activity_to_column_value
    import = generate_import_with_mapping
    import.mapping.merge!('activity' => '5')
    import.save!

    # N.B. last row is not imported due to the usage of a disabled activity
    first, second, third = new_records(TimeEntry, 3) { import.run }

    assert_equal 9,  first.activity_id
    assert_equal 10, second.activity_id
    assert_equal 11, third.activity_id

    last = import.items.last
    assert_equal 'Activity cannot be blank', last.message
    assert_nil last.obj_id
  end

  def test_maps_activity_to_fixed_value
    import = generate_import_with_mapping
    first, second, third, fourth = new_records(TimeEntry, 4) { import.run }

    assert_equal 10, first.activity_id
    assert_equal 10, second.activity_id
    assert_equal 10, third.activity_id
    assert_equal 10, fourth.activity_id
  end

  def test_maps_custom_fields
    overtime_cf = CustomField.find(10)

    import = generate_import_with_mapping
    import.mapping.merge!('cf_10' => '6')
    import.save!
    first, second, third, fourth = new_records(TimeEntry, 4) { import.run }

    assert_equal '1', first.custom_field_value(overtime_cf)
    assert_equal '1', second.custom_field_value(overtime_cf)
    assert_equal '0', third.custom_field_value(overtime_cf)
    assert_equal '0', fourth.custom_field_value(overtime_cf)
  end

  protected

  def generate_import(fixture_name='import_time_entries.csv')
    import = TimeEntryImport.new
    import.user_id = 2
    import.file = uploaded_test_file(fixture_name, 'text/csv')
    import.save!
    import
  end

  def generate_import_with_mapping(fixture_name='import_time_entries.csv')
    import = generate_import(fixture_name)

    import.settings = {
      'separator' => ';', 'wrapper' => '"', 'encoding' => 'UTF-8',
      'mapping' => {
        'project_id' => '1',
        'activity'   => 'value:10',
        'issue_id'   => '1',
        'spent_on'   => '2',
        'hours'      => '3',
        'comments'   => '4'
      }
    }
    import.save!
    import
  end
end
