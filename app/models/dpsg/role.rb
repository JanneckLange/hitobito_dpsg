# frozen_string_literal: true

#  Copyright (c) 2012-2026, Deutsche Pfadfinderschaft Sankt Georg e.V. This file is part of
#  hitobito_dpsg and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_dpsg.

module Dpsg
  module Role
    extend ActiveSupport::Concern

    included do
      class_attribute :beitragspflichtig
      self.beitragspflichtig = false

      validate :assert_active_mitglieder_role_for_beitragspflichtig, on: :create
    end

    def beitragspflichtig_type?
      return false if new_record? && type.nil? && instance_of?(::Role)

      role_type = type.safe_constantize || self.class
      role_type.respond_to?(:beitragspflichtig) && role_type.beitragspflichtig
    end

    private

    def assert_active_mitglieder_role_for_beitragspflichtig
      return unless beitragspflichtig_type?
      return if person.blank?

      mitglieder_role_types = ::Group::Mitglieder.role_types.map(&:sti_name)
      return if mitglieder_role_types.empty?

      has_active_mitglieder_role = person.roles
        .with_inactive
        .active
        .where(type: mitglieder_role_types)
        .exists?

      errors.add(:base, :missing_mitglieder_role_for_beitragspflichtig) unless has_active_mitglieder_role
    end
  end
end
