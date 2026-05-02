# frozen_string_literal: true

#  Copyright (c) 2012-2026, Deutsche Pfadfinderschaft Sankt Georg e.V. This file is part of
#  hitobito_dpsg and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_dpsg.

module Dpsg
  module GroupDecorator
    extend ActiveSupport::Concern

    prepended do
      # Override primary_group_toggle_link to prevent setting Group::Mitglieder as primary group
    end

    # Prevent Group::Mitglieder from being set as the primary group.
    # Membership roles must not be primary roles.
    def primary_group_toggle_link(person, group, title: I18n.t("people.roles_aside.set_main_group"))
      return if model.is_a?(Group::Mitglieder)

      # Call the original method from the parent decorator
      super(person, group, title: title)
    end
  end
end
