# frozen_string_literal: true

#  Copyright (c) 2012-2026, Deutsche Pfadfinderschaft Sankt Georg e.V. This file is part of
#  hitobito_dpsg and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_dpsg.

module Dpsg
  # Resolves the Group::Mitglieder group and its membership role for a person
  # relative to the layer of a given (beitragspflichtig) role's group.
  #
  # Usage:
  #   resolver = Dpsg::MembershipRoleResolver.new(bibergruppe_instance)
  #   resolver.create_or_replace(person: person, role_type: Group::Mitglieder::OrdentlicheMitgliedschaft)
  class MembershipRoleResolver
    def initialize(group)
      @group = group
    end

    # Returns the Group::Mitglieder instance that is a direct child of the layer group,
    # or nil if none exists yet.
    def mitglieder_group
      @mitglieder_group ||= Group::Mitglieder.where(parent_id: @group.layer_group_id).first
    end

    # The available membership role types (always the same regardless of layer).
    def available_role_types
      Group::Mitglieder.role_types
    end

    # Returns the person's current active Group::Mitglieder role (any Mitglieder group), or nil.
    def active_mitglieder_role(person)
      person.roles
        .where(type: available_role_types.map(&:sti_name))
        .first
    end

    # Creates a new Mitglieder role for +person+ of +role_type+ within the layer's Mitglieder
    # group.  If the person already has an active Mitglieder role:
    #   - same type → no-op, returns existing role
    #   - different type → destroys old role (bypassing Invariante C) and creates new one
    #
    # Returns the persisted Mitglieder role, or raises ActiveRecord::RecordInvalid on failure.
    def create_or_replace(person:, role_type:)
      return unless role_type
      raise ArgumentError, "No Group::Mitglieder found for layer #{@group.layer_group_id}" unless mitglieder_group

      existing = active_mitglieder_role(person)

      if existing
        return existing if existing.type == role_type.sti_name

        # Type swap: bypass Invariante C by setting the swap flag before destroy.
        existing.instance_variable_set(:@allow_membership_role_swap, true)
        existing.destroy!
      end

      role_type.create!(person: person, group: mitglieder_group)
    end
  end
end
