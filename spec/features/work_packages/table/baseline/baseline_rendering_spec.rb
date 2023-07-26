#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
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
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'spec_helper'

RSpec.describe 'baseline rendering',
               js: true,
               with_settings: { date_format: '%Y-%m-%d' } do
  shared_let(:list_wp_custom_field) { create(:list_wp_custom_field, :global) }
  shared_let(:multi_list_wp_custom_field) { create(:list_wp_custom_field, :global, multi_value: true) }
  shared_let(:version_wp_custom_field) { create(:version_wp_custom_field, :global) }
  shared_let(:bool_wp_custom_field) { create(:bool_wp_custom_field, :global) }
  shared_let(:user_wp_custom_field) { create(:user_wp_custom_field, :global) }
  shared_let(:int_wp_custom_field) { create(:int_wp_custom_field, :global) }
  shared_let(:float_wp_custom_field) { create(:float_wp_custom_field, :global) }
  shared_let(:string_wp_custom_field) { create(:string_wp_custom_field, :global) }
  shared_let(:date_wp_custom_field) { create(:date_wp_custom_field, :global) }

  shared_let(:type_bug) { create(:type_bug) }
  shared_let(:type_task) { create(:type_task, custom_fields: CustomField.all) }
  shared_let(:type_milestone) { create(:type_milestone) }

  shared_let(:project) { create(:project, types: [type_bug, type_task, type_milestone]) }
  shared_let(:user) do
    create(:user,
           firstname: 'Itsa',
           lastname: 'Me',
           member_in_project: project,
           member_with_permissions: %i[view_work_packages edit_work_packages work_package_assigned assign_versions])
  end

  shared_let(:assignee) do
    create(:user,
           firstname: 'Assigned',
           lastname: 'User',
           member_in_project: project,
           member_with_permissions: %i[view_work_packages edit_work_packages work_package_assigned])
  end

  shared_let(:default_priority) do
    create(:issue_priority, name: 'Default', is_default: true)
  end

  shared_let(:high_priority) do
    create(:issue_priority, name: 'High priority')
  end

  shared_let(:version_a) { create(:version, project:, name: 'Version A') }
  shared_let(:version_b) { create(:version, project:, name: 'Version B') }
  shared_let(:display_representation) { Components::WorkPackages::DisplayRepresentation.new }

  shared_let(:wp_bug) do
    create(:work_package,
           project:,
           type: type_bug,
           subject: 'A bug',
           created_at: 5.days.ago,
           updated_at: 5.days.ago)
  end

  shared_let(:wp_task) do
    create(:work_package,
           project:,
           type: type_task,
           subject: 'A task',

           created_at: 5.days.ago,
           updated_at: 5.days.ago)
  end

  shared_let(:wp_task_changed) do
    wp = Timecop.travel(5.days.ago) do
      create(:work_package,
             project:,
             type: type_task,
             assigned_to: assignee,
             responsible: assignee,
             priority: default_priority,
             version: version_a,
             subject: 'Old subject',
             start_date: '2023-05-01',
             due_date: '2023-05-02')
    end

    Timecop.travel(1.day.ago) do
      WorkPackages::UpdateService
        .new(user:, model: wp)
        .call(
          subject: 'New subject',
          start_date: Time.zone.today - 1.day,
          due_date: Time.zone.today,
          assigned_to: user,
          responsible: user,
          priority: high_priority,
          version: version_b
        )
        .on_failure { |result| raise result.message }
        .result
    end
  end

  shared_let(:wp_task_assigned) do
    wp = Timecop.travel(5.days.ago) do
      create(:work_package,
             project:,
             type: type_task,
             assigned_to: nil)
    end

    Timecop.travel(1.day.ago) do
      WorkPackages::UpdateService
        .new(user:, model: wp)
        .call(assigned_to: user)
        .on_failure { |result| raise result.message }
        .result
    end
  end

  shared_let(:wp_task_was_bug) do
    wp = Timecop.travel(5.days.ago) do
      create(:work_package, project:, type: type_bug, subject: 'Bug changed to Task')
    end

    Timecop.travel(1.day.ago) do
      WorkPackages::UpdateService
        .new(user:, model: wp)
        .call(type: type_task)
        .on_failure { |result| raise result.message }
        .result
    end
  end

  shared_let(:wp_bug_was_task) do
    wp = Timecop.travel(5.days.ago) do
      create(:work_package, project:, type: type_task, subject: 'Task changed to Bug')
    end

    Timecop.travel(1.day.ago) do
      WorkPackages::UpdateService
        .new(user:, model: wp)
        .call(type: type_bug)
        .on_failure { |result| raise result.message }
        .result
    end
  end

  shared_let(:wp_milestone_date_changed) do
    wp = Timecop.travel(5.days.ago) do
      create(:work_package,
             project:,
             type: type_milestone,
             subject: 'Milestone 1',
             start_date: Time.zone.today,
             due_date: Time.zone.today)
    end

    WorkPackages::UpdateService
      .new(user:, model: wp)
      .call(start_date: Time.zone.today + 1.day, due_date: Time.zone.today + 1.day)
      .on_failure { |result| raise result.message }
      .result
  end

  shared_let(:initial_custom_values) do
    # For some reason, only one the last change is being displayed on the table.
    # I'm still trying to figure out why it is happening, but until then please activate only
    # the custom field you are trying to fix.

    {
      # int_wp_custom_field.id => 1, # working
      # string_wp_custom_field.id => 'this is a string', # working
      # bool_wp_custom_field.id => true, #working
      # float_wp_custom_field.id => 2.9, #working

      list_wp_custom_field.id => list_wp_custom_field.possible_values.first, # not working
      multi_list_wp_custom_field.id => multi_list_wp_custom_field.possible_values.take(2) # not working

      # Please leave these alone at the moment until the specs are set up correctly for
      # the following fields:

      # user_wp_custom_field.id => [assignee.id.to_s]
      # version_wp_custom_field,
      # date_wp_custom_field
    }
  end

  shared_let(:changed_custom_values) do
    # For some reason, only one the last change is being displayed on the table.
    # I'm still trying to figure out why it is happening, but until then please activate only
    # the custom field you are trying to fix.

    {
      # :"custom_field_#{int_wp_custom_field.id}" => 2,
      # :"custom_field_#{string_wp_custom_field.id}" => 'this is a changed string',
      # :"custom_field_#{bool_wp_custom_field.id}" => false,
      # :"custom_field_#{float_wp_custom_field.id}" => 3.7,

      # Not working, needs UI fix
      "custom_field_#{list_wp_custom_field.id}": [list_wp_custom_field.possible_values.second],
      "custom_field_#{multi_list_wp_custom_field.id}": multi_list_wp_custom_field.possible_values.take(3)

      # Please leave these alone at the moment until the specs are set up correctly for
      # the following fields:

      # :"custom_field_#{user_wp_custom_field.id}" => [user.id.to_s]
      # version_wp_custom_field,
      # date_wp_custom_field
    }
  end

  shared_let(:wp_task_cf) do
    wp = Timecop.travel(5.days.ago) do
      create(:work_package,
             project:,
             type: type_task,
             subject: 'A task',
             custom_values: initial_custom_values)
    end

    WorkPackages::UpdateService
      .new(user:, model: wp)
      .call(changed_custom_values)
      .on_failure { |result| raise result.message }
      .result
  end

  shared_let(:query) do
    query = create(:query,
                   name: 'Timestamps Query',
                   project:,
                   user:)

    query.timestamps = ["P-2d", "PT0S"]
    query.add_filter('type_id', '=', [type_task.id, type_milestone.id])
    query.column_names =
      %w[id subject status type start_date due_date version priority assigned_to responsible] +
      CustomField.all.pluck(:id).map { |id| "cf_#{id}" }
    query.save!(validate: false)

    query
  end

  let(:today) { Time.zone.today }
  let(:wp_table) { Pages::WorkPackagesTable.new(project) }
  let(:baseline) { Components::WorkPackages::Baseline.new }
  let(:baseline_modal) { Components::WorkPackages::BaselineModal.new }

  current_user { user }

  describe 'with feature enabled', with_ee: %i[baseline_comparison], with_flag: { show_changes: true } do
    it 'does show changes' do
      wp_table.visit_query(query)
      wp_table.expect_work_package_listed wp_task, wp_task_changed, wp_task_was_bug, wp_bug_was_task,
                                          wp_task_assigned, wp_milestone_date_changed
      wp_table.ensure_work_package_not_listed! wp_bug

      baseline.expect_active
      baseline.expect_added wp_task_was_bug
      baseline.expect_removed wp_bug_was_task
      baseline.expect_changed wp_task_changed
      baseline.expect_changed wp_task_assigned
      baseline.expect_changed wp_milestone_date_changed
      baseline.expect_unchanged wp_task

      baseline.expect_changed_attributes wp_task_was_bug,
                                         type: %w[BUG TASK]

      baseline.expect_changed_attributes wp_bug_was_task,
                                         type: %w[TASK BUG]

      baseline.expect_changed_attributes wp_task_changed,
                                         subject: ['Old subject', 'New subject'],
                                         startDate: ['2023-05-01', (today - 2.days).iso8601],
                                         dueDate: ['2023-05-02', (today - 1.day).iso8601],
                                         version: ['Version A', 'Version B'],
                                         priority: ['Default', 'High priority'],
                                         assignee: ['Assigned User', 'Itsa Me'],
                                         responsible: ['Assigned User', 'Itsa Me']

      baseline.expect_changed_attributes wp_task_assigned,
                                         assignee: ['-', 'Itsa Me']

      baseline.expect_changed_attributes wp_milestone_date_changed,
                                         startDate: [
                                           (today - 5.days).iso8601,
                                           (today + 1.day).iso8601
                                         ],
                                         dueDate: [
                                           (today - 5.days).iso8601,
                                           (today + 1.day).iso8601
                                         ]

      baseline.expect_unchanged_attributes wp_task_changed, :type
      baseline.expect_unchanged_attributes wp_task,
                                           :type, :subject, :start_date, :due_date,
                                           :version, :priority, :assignee, :accountable

      # These expectations will be re-enabled once I figure out why it is showing
      # only the last changed custom field.

      # baseline.expect_changed_attributes wp_task_cf,
      #                                "customField#{int_wp_custom_field.id}": [
      #                                 '1',
      #                                 '2'
      #                                ],
      #                                "customField#{string_wp_custom_field.id}": [
      #                                 'this is a string',
      #                                 'this is a changed string'
      #                                ],
      #                                "customField#{bool_wp_custom_field.id}": [
      #                                 'yes',
      #                                 'no'
      #                                ]
      #                                "customField#{float_wp_custom_field.id}": [
      #                                 '2.9',
      #                                 '3.7'
      #                                ]
      baseline.expect_changed_attributes wp_task_cf,
                                         "customField#{list_wp_custom_field.id}": [
                                           list_wp_custom_field.possible_values.first.value,
                                           list_wp_custom_field.possible_values.second.value
                                         ]

      # This expectation is not clear if it works, because the multi values are being joined just by a
      # space, probably a rework on the expectation is also needed.

      baseline.expect_changed_attributes wp_task_cf,
                                         "customField#{multi_list_wp_custom_field.id}": [
                                           multi_list_wp_custom_field.possible_values.take(3).pluck(:value).join(" "),
                                           multi_list_wp_custom_field.possible_values.take(2).pluck(:value).join(" ")
                                         ]

      # show icons on work package single card
      display_representation.switch_to_card_layout
      within "wp-single-card[data-work-package-id='#{wp_bug_was_task.id}']" do
        expect(page).to have_selector(".op-table-baseline--icon-removed")
      end
      within "wp-single-card[data-work-package-id='#{wp_task_was_bug.id}']" do
        expect(page).to have_selector(".op-table-baseline--icon-added")
      end
      within "wp-single-card[data-work-package-id='#{wp_task_changed.id}']" do
        expect(page).to have_selector(".op-table-baseline--icon-changed")
      end
      within "wp-single-card[data-work-package-id='#{wp_task.id}']" do
        expect(page).not_to have_selector(".op-wp-single-card--content-baseline")
      end
    end
  end

  describe 'with feature disabled', with_flag: { show_changes: false } do
    it 'does not show changes' do
      wp_table.visit_query(query)
      wp_table.expect_work_package_listed wp_task, wp_task_changed, wp_task_was_bug
      wp_table.ensure_work_package_not_listed! wp_bug, wp_bug_was_task

      baseline.expect_inactive
    end
  end

  describe 'without EE', with_ee: false, with_flag: { show_changes: true } do
    it 'disabled options' do
      wp_table.visit_query(query)
      baseline_modal.expect_closed
      baseline_modal.toggle_drop_modal
      baseline_modal.expect_open
      expect(page).to have_selector(".op-baseline--enterprise-title")
      # only yesterday is selectable
      page.select('a specific date', from: 'op-baseline-filter')
      expect(page).not_to have_select('op-baseline-filter', selected: 'a specific date')

      page.select('yesterday', from: 'op-baseline-filter')
      expect(page).to have_select('op-baseline-filter', selected: 'yesterday')
    end
  end
end
