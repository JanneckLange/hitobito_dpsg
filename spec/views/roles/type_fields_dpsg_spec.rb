# frozen_string_literal: true

#  Copyright (c) 2012-2026, Deutsche Pfadfinderschaft Sankt Georg e.V. This file is part of
#  hitobito_dpsg and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_dpsg.

require 'spec_helper'

describe 'roles/_type_fields_dpsg.html.haml' do
  let(:group) { groups(:bibergruppe) }
  let(:person) { Fabricate(:person) }
  let(:role) { group.roles.build(person: person, type: 'Group::Bibergruppe::Mitglied') }

  before do
    # Mock the helper method
    allow(view).to receive(:mitglieder_role_type_options).and_return([
      Group::Mitglieder::OrdentlicheMitgliedschaft,
      Group::Mitglieder::Foerdermitgliedschaft,
      Group::Mitglieder::Zweitmitgliedschaft
    ])
  end

  context 'for beitragspflichtig role' do
    it 'renders the mitgliedschaft dropdown' do
      render partial: 'roles/type_fields_dpsg', locals: { entry: role, f: form_for(role) }

      expect(rendered).to include('mitgliedschaft_role_type')
      expect(rendered).to include('form-select')
    end

    it 'includes turbo frame' do
      render partial: 'roles/type_fields_dpsg', locals: { entry: role, f: form_for(role) }

      expect(rendered).to include('role_mitgliedschaft_type')
      expect(rendered).to include('turbo-frame')
    end
  end

  context 'for non-beitragspflichtig role' do
    let(:role) { group.roles.build(person: person, type: 'Group::Bibergruppe::Helfer') }

    it 'does not render the dropdown' do
      render partial: 'roles/type_fields_dpsg', locals: { entry: role, f: form_for(role) }

      expect(rendered).not_to include('mitgliedschaft_role_type')
    end
  end
end
