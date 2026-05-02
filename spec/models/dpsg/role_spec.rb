# frozen_string_literal: true

#  Copyright (c) 2012-2026, Deutsche Pfadfinderschaft Sankt Georg e.V. This file is part of
#  hitobito_dpsg and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_dpsg.

require "spec_helper"

# Shared setup: build a minimal group hierarchy
#   stamm (layer)
#     └─ mitglieder_group  (Group::Mitglieder)
#     └─ gruppen           (Group::Gruppen)
#         └─ bibergruppe   (Group::Bibergruppe)
#
# This mirrors the real pfadi_de / dpsg production structure.
RSpec.describe "Dpsg beitragspflichtig Rollenlogik" do
  let(:stamm) do
    Fabricate(Group::Stamm.name, parent: groups(:root))
  end
  let(:mitglieder_group) do
    Fabricate(Group::Mitglieder.name, parent: stamm)
  end
  let(:gruppen) do
    Fabricate(Group::Gruppen.name, parent: stamm)
  end
  let(:bibergruppe) do
    Fabricate(Group::Bibergruppe.name, parent: gruppen)
  end
  let(:person) { Fabricate(:person) }

  # Ensure the group hierarchy (and therefore layer_group_id) is fully persisted.
  before do
    stamm
    mitglieder_group
    gruppen
    bibergruppe
  end

  # Helper to create a Biber role without triggering the mitgliedschaft validation
  # (used to set up the "existing beitragspflichtig role" scenario).
  def create_biber_role(person: self.person, with_mitglieder: true)
    biber = Group::Bibergruppe::Mitglied.new(person: person, group: bibergruppe,
      start_on: Date.current)
    biber.mitgliedschaft_role_type = Group::Mitglieder::OrdentlicheMitgliedschaft.sti_name
    biber.save!
    biber
  end

  def create_ordentliche_mitgliedschaft(person: self.person)
    Group::Mitglieder::OrdentlicheMitgliedschaft.create!(
      person: person, group: mitglieder_group, start_on: Date.current
    )
  end

  # ---------------------------------------------------------------------------
  # beitragspflichtig Flag
  # ---------------------------------------------------------------------------
  describe "beitragspflichtig Flag" do
    it "ist bei Biber gesetzt" do
      expect(Group::Bibergruppe::Mitglied.beitragspflichtig).to be true
    end

    it "ist bei Woelfling gesetzt" do
      expect(Group::Woelflingsmeute::Woelfling.beitragspflichtig).to be true
    end

    it "ist bei Jungpfadfinder gesetzt" do
      expect(Group::Jungpfadfindertrupp::Jungpfadfinder.beitragspflichtig).to be true
    end

    it "ist bei Pfadfinder gesetzt" do
      expect(Group::Pfadfindertrupp::Pfadfinder.beitragspflichtig).to be true
    end

    it "ist bei Rover gesetzt" do
      expect(Group::Roverrunde::Rover.beitragspflichtig).to be true
    end

    it "ist bei Leitungsrollen nicht gesetzt" do
      expect(Group::Woelflingsmeute::Leitwoelfling.beitragspflichtig).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # Invariante B: Pflichtauswahl Mitgliedschaft
  # ---------------------------------------------------------------------------
  describe "Invariante B: Mitgliedschaft ist Pflicht" do
    it "ist ungültig ohne mitgliedschaft_role_type" do
      role = Group::Bibergruppe::Mitglied.new(person: person, group: bibergruppe,
        start_on: Date.current)
      expect(role).not_to be_valid
      expect(role.errors[:mitgliedschaft_role_type]).to be_present
    end

    it "ist gültig mit mitgliedschaft_role_type" do
      role = Group::Bibergruppe::Mitglied.new(
        person: person, group: bibergruppe, start_on: Date.current,
        mitgliedschaft_role_type: Group::Mitglieder::OrdentlicheMitgliedschaft.sti_name
      )
      expect(role).to be_valid
    end

    it "validiert bei nicht-beitragspflichtigen Rollen nicht" do
      role = Group::Woelflingsmeute::Leitwoelfling.new(
        person: person, group: bibergruppe, start_on: Date.current
      )
      # Should not have errors on mitgliedschaft_role_type (other validations may exist)
      role.valid?
      expect(role.errors[:mitgliedschaft_role_type]).to be_empty
    end
  end

  # ---------------------------------------------------------------------------
  # Invariante A: Nur eine aktive Mitglieder-Rolle pro Person
  # ---------------------------------------------------------------------------
  describe "Invariante A: Exklusivität Mitglieder-Rolle" do
    it "verhindert eine zweite aktive Mitglieder-Rolle (manuell)" do
      create_ordentliche_mitgliedschaft

      duplicate = Group::Mitglieder::Foerdermitgliedschaft.new(
        person: person, group: mitglieder_group, start_on: Date.current
      )
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:base]).to include(
        I18n.t("activerecord.errors.models.role.attributes.base.single_mitglieder_role_per_person")
      )
    end

    it "erlaubt die erste Mitglieder-Rolle" do
      role = Group::Mitglieder::OrdentlicheMitgliedschaft.new(
        person: person, group: mitglieder_group, start_on: Date.current
      )
      expect(role).to be_valid
    end

    it "erlaubt eine zweite Mitglieder-Rolle für eine ANDERE Person" do
      other_person = Fabricate(:person)
      create_ordentliche_mitgliedschaft(person: other_person)

      role = Group::Mitglieder::OrdentlicheMitgliedschaft.new(
        person: person, group: mitglieder_group, start_on: Date.current
      )
      expect(role).to be_valid
    end
  end

  # ---------------------------------------------------------------------------
  # Invariante C: Löschschutz Mitglieder-Rolle
  # ---------------------------------------------------------------------------
  describe "Invariante C: Löschschutz Mitglieder-Rolle" do
    it "verhindert das Löschen, wenn eine aktive beitragspflichtige Rolle existiert" do
      create_biber_role
      mitglieder_role = person.roles.where(type: Group::Mitglieder.role_types.map(&:sti_name)).first
      expect(mitglieder_role).to be_present

      expect { mitglieder_role.destroy }.not_to change { person.roles.count }
      expect(mitglieder_role.errors[:base]).to include(
        I18n.t("activerecord.errors.models.role.attributes.base.protected_by_beitragspflichtig_role")
      )
    end

    it "erlaubt das Löschen, wenn keine aktive beitragspflichtige Rolle mehr existiert" do
      biber = create_biber_role
      mitglieder_role = person.roles.where(type: Group::Mitglieder.role_types.map(&:sti_name)).first

      # End the biber role (soft delete by setting end_on to yesterday)
      biber.update_column(:end_on, Date.yesterday)

      expect { mitglieder_role.destroy }.to change {
        person.roles.with_inactive.where(type: Group::Mitglieder.role_types.map(&:sti_name)).count
      }.by(-1)
    end
  end

  # ---------------------------------------------------------------------------
  # Aufräumlogik: Mitglieder-Rolle automatisch entfernen
  # ---------------------------------------------------------------------------
  describe "Aufräumlogik: automatisches Entfernen der Mitglieder-Rolle" do
    it "entfernt die Mitglieder-Rolle, wenn die letzte beitragspflichtige Rolle gelöscht wird" do
      biber = create_biber_role
      expect(person.roles.where(type: Group::Mitglieder.role_types.map(&:sti_name))).to exist

      biber.destroy

      expect(person.roles.with_inactive.where(type: Group::Mitglieder.role_types.map(&:sti_name)))
        .not_to exist
    end

    it "behält die Mitglieder-Rolle, wenn noch weitere beitragspflichtige Rollen vorhanden sind" do
      woelflingsmeute = Fabricate(Group::Woelflingsmeute.name, parent: gruppen)
      biber = create_biber_role

      woelfling = Group::Woelflingsmeute::Woelfling.new(
        person: person, group: woelflingsmeute, start_on: Date.current,
        mitgliedschaft_role_type: Group::Mitglieder::OrdentlicheMitgliedschaft.sti_name
      )
      # Woelfling already finds an existing active Mitglieder role → skip creation
      woelfling.mitgliedschaft_role_type = nil # bypass validation for this setup
      woelfling.save!(validate: false)

      mitglieder_count_before = person.roles.with_inactive
        .where(type: Group::Mitglieder.role_types.map(&:sti_name)).count

      biber.destroy

      expect(person.roles.with_inactive.where(type: Group::Mitglieder.role_types.map(&:sti_name)).count)
        .to eq(mitglieder_count_before)
    end
  end

  # ---------------------------------------------------------------------------
  # MembershipRoleResolver
  # ---------------------------------------------------------------------------
  describe Dpsg::MembershipRoleResolver do
    subject(:resolver) { described_class.new(bibergruppe) }

    describe "#mitglieder_group" do
      it "findet die Mitglieder-Gruppe des Layers" do
        expect(resolver.mitglieder_group).to eq(mitglieder_group)
      end

      it "gibt nil zurück, wenn keine Mitglieder-Gruppe vorhanden ist" do
        bibergruppe_without_mitglieder = Fabricate(Group::Bibergruppe.name, parent: gruppen)
        mitglieder_group.destroy!
        resolver2 = described_class.new(bibergruppe_without_mitglieder)
        expect(resolver2.mitglieder_group).to be_nil
      end
    end

    describe "#create_or_replace" do
      it "legt eine neue Mitglieder-Rolle an, wenn noch keine vorhanden ist" do
        expect {
          resolver.create_or_replace(
            person: person,
            role_type: Group::Mitglieder::OrdentlicheMitgliedschaft
          )
        }.to change { person.roles.count }.by(1)

        expect(person.roles.where(type: "Group::Mitglieder::OrdentlicheMitgliedschaft")).to exist
      end

      it "gibt die vorhandene Rolle zurück, wenn der Typ bereits passt (no-op)" do
        existing = create_ordentliche_mitgliedschaft

        result = nil
        expect {
          result = resolver.create_or_replace(
            person: person,
            role_type: Group::Mitglieder::OrdentlicheMitgliedschaft
          )
        }.not_to change { person.roles.count }

        expect(result).to eq(existing)
      end

      it "ersetzt die vorhandene Mitglieder-Rolle, wenn der Typ abweicht" do
        create_ordentliche_mitgliedschaft

        resolver.create_or_replace(
          person: person,
          role_type: Group::Mitglieder::Foerdermitgliedschaft
        )

        active_mitglieder = person.roles.where(type: Group::Mitglieder.role_types.map(&:sti_name))
        expect(active_mitglieder.count).to eq(1)
        expect(active_mitglieder.first.type).to eq("Group::Mitglieder::Foerdermitgliedschaft")
      end
    end
  end
end
