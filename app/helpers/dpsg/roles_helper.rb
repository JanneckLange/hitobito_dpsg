# frozen_string_literal: true

#  Copyright (c) 2012-2026, Deutsche Pfadfinderschaft Sankt Georg e.V. This file is part of
#  hitobito_dpsg and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_dpsg.

module Dpsg
  module RolesHelper
    def role_type_option_label(role_type)
      return role_type.label unless fee_relevant_role_type?(role_type)

      "#{role_type.label} [EUR]"
    end

    private

    def fee_relevant_role_type?(role_type)
      beitragspflichtig = role_type.respond_to?(:beitragspflichtig) && role_type.beitragspflichtig
      has_fee_kind = role_type.respond_to?(:has_fee_kind) && role_type.has_fee_kind
      beitragspflichtig || has_fee_kind
    end
  end
end
