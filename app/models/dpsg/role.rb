# frozen_string_literal: true

#  Copyright (c) 2012-2026, Deutsche Pfadfinderschaft Sankt Georg e.V. This file is part of
#  hitobito_dpsg and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_dpsg.

module Dpsg
  module Role
    extend ActiveSupport::Concern

    included do
      # Marks a role type as requiring a linked Group::Mitglieder membership role.
      # Set `self.beitragspflichtig = true` on any role class to opt in.
      class_attribute :beitragspflichtig, default: false

      # Virtual attribute: STI class name of the desired Group::Mitglieder role type.
      # Set by the controller from the "Mitgliedschaft" dropdown param.
      attr_accessor :mitgliedschaft_role_type

      # Invariante B: Selecting a Mitgliedschaft type is mandatory for beitragspflichtig roles.
      validates :mitgliedschaft_role_type, presence: true, if: :beitragspflichtig_and_new_record?

      # Invariante A: Each person may have at most one active Mitglieder role at any time.
      # This fires for every Group::Mitglieder role, preventing manual duplicates as well.
      validate :assert_single_active_mitglieder_role, if: :mitglieder_role?

      # Invariante C: An active Mitglieder role cannot be removed while the person still
      # holds at least one active beitragspflichtig role.
      before_destroy :prevent_destroy_with_active_beitragspflichtig_role, if: :mitglieder_role?

      # Aufräumlogik: When the last active beitragspflichtig role of a person is destroyed,
      # the person's active Mitglieder role is automatically removed as well.
      after_commit :cleanup_mitglieder_role_if_needed, on: :destroy, if: :beitragspflichtig_type?
    end

    # ---- public helpers used by views / controller ----

    def beitragspflichtig_type?
      self.class.beitragspflichtig
    end

    def mitglieder_role?
      group.is_a?(Group::Mitglieder)
    end

    private

    def beitragspflichtig_and_new_record?
      beitragspflichtig_type? && new_record?
    end

    # --- Invariante A ---

    def assert_single_active_mitglieder_role
      return unless person

      scope = person.roles
        .where(type: Group::Mitglieder.role_types.map(&:sti_name))
      scope = scope.where.not(id: id) unless new_record?

      if scope.exists?
        errors.add(:base, :single_mitglieder_role_per_person)
      end
    end

    # --- Invariante C ---

    def prevent_destroy_with_active_beitragspflichtig_role
      # The @allow_membership_role_swap flag is set by MembershipRoleResolver when it
      # intentionally replaces a Mitglieder role during a type swap.
      return if @allow_membership_role_swap

      beitragspflichtig_types = ::Role.all_types.select(&:beitragspflichtig).map(&:sti_name)
      return if beitragspflichtig_types.empty?

      if person.roles.where(type: beitragspflichtig_types).exists?
        errors.add(:base, :protected_by_beitragspflichtig_role)
        throw(:abort)
      end
    end

    # --- Aufräumlogik ---

    def cleanup_mitglieder_role_if_needed
      return unless person

      beitragspflichtig_types = ::Role.all_types.select(&:beitragspflichtig).map(&:sti_name)
      return if beitragspflichtig_types.empty?

      # If person still has active beitragspflichtig roles, keep the Mitglieder role.
      return if person.roles.where(type: beitragspflichtig_types).exists?

      mitglieder_role = person.roles
        .where(type: Group::Mitglieder.role_types.map(&:sti_name))
        .first
      return unless mitglieder_role

      # Bypass Invariante C since we are intentionally removing the Mitglieder role.
      mitglieder_role.instance_variable_set(:@allow_membership_role_swap, true)
      mitglieder_role.destroy
    end
  end
end
