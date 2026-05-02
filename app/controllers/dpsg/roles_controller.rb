# frozen_string_literal: true

#  Copyright (c) 2012-2026, Deutsche Pfadfinderschaft Sankt Georg e.V. This file is part of
#  hitobito_dpsg and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_dpsg.

module Dpsg
  module RolesController
    extend ActiveSupport::Concern

    prepended do
      helper_method :mitglieder_role_type_options
    end

    # Override create to:
    # 1. Handle autosubmit (re-render form when role type changes so the Mitgliedschaft
    #    dropdown appears/disappears dynamically).
    # 2. For beitragspflichtig roles: wrap save + MembershipRoleResolver call in one
    #    transaction so both roles are committed or rolled back atomically.
    def create
      if params[:autosubmit].present?
        assign_attributes
        render "new"
      elsif entry.class.beitragspflichtig
        create_with_mitglieder_role
      else
        super
      end
    end

    private

    # Replicates RolesController#create_entry_and_person exactly, but also calls
    # MembershipRoleResolver inside the same transaction.
    def create_with_mitglieder_role
      # Assign model_params so that mitgliedschaft_role_type virtual attr is set.
      assign_attributes
      created = false
      ::Role.transaction do
        created = with_callbacks(:create, :save) do
          (entry.person.persisted? || (privacy_policy_accepted? && entry.person.save)) &&
            entry.save
        end
        if created
          Dpsg::MembershipRoleResolver
            .new(entry.group)
            .create_or_replace(
              person: entry.person,
              role_type: entry.mitgliedschaft_role_type&.safe_constantize
            )
        end
        raise ActiveRecord::Rollback unless created
      end

      with_person_add_request_redirect_guard do
        respond_with(entry, success: created, location: after_create_location(false))
      end
    end

    # Guard: if Person::AddRequest redirected, skip respond_with.
    def with_person_add_request_redirect_guard
      yield unless performed?
    end

    def mitglieder_role_type_options
      Group::Mitglieder.role_types
    end

    def permitted_attrs(role_type = entry.class)
      attrs = super
      role_type.beitragspflichtig ? attrs + [:mitgliedschaft_role_type] : attrs
    end
  end
end
