# frozen_string_literal: true

#  Copyright (c) 2012-2026, Deutsche Pfadfinderschaft Sankt Georg e.V. This file is part of
#  hitobito_dpsg and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_dpsg.

require 'spec_helper'

describe 'Creating role with beitragspflichtig type' do
  let(:stamm) { groups(:stamm) }
  let(:bibergruppe) { groups(:bibergruppe) }
  let(:person) { Fabricate(:person, first_name: 'John', last_name: 'Doe') }

  before do
    login_as(people(:admin), scope: :person)
  end

  it 'shows mitgliedschaft dropdown when selecting beitragsplichtig role' do
    # Navigate to create role form for person
    visit group_person_roles_path(stamm, person)
    click_link 'Rolle hinzufügen'

    # Select the bibergruppe group
    select 'Biber', from: 'role_type'
    wait_for_ajax

    # Check if mitgliedschaft dropdown is visible
    expect(page).to have_field('role_mitgliedschaft_role_type')
  end

  it 'shows validation error when mitgliedschaft is not selected' do
    visit group_person_roles_path(stamm, person)
    click_link 'Rolle hinzufügen'

    select 'Biber', from: 'role_type'
    wait_for_ajax

    click_button 'Speichern'

    expect(page).to have_text('muss bei beitragspflichtigen Rollen ausgewählt werden')
  end

  it 'creates role with mitgliedschaft when selected' do
    visit group_person_roles_path(stamm, person)
    click_link 'Rolle hinzufügen'

    select 'Biber', from: 'role_type'
    wait_for_ajax

    select 'Ordentliche Mitgliedschaft', from: 'role_mitgliedschaft_role_type'
    click_button 'Speichern'

    expect(page).to have_text('Rolle wurde erfolgreich erstellt')

    # Verify both roles were created
    expect(person.reload.roles.count).to eq(2)
    expect(person.roles.map(&:type)).to include(
      'Group::Bibergruppe::Mitglied',
      'Group::Mitglieder::OrdentlicheMitgliedschaft'
    )
  end
end
