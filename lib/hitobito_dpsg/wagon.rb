# frozen_string_literal: true

#  Copyright (c) 2012-2026, Deutsche Pfadfinder*innenschaft Sankt Georg. This file is part of
#  hitobito_dpsg and licensed under the Affero General Public License version 3
#  or later. See the COPYING file at the top-level directory or at
#  https://github.com/hitobito/hitobito_dpsg.

module HitobitoDpsg
  class Wagon < Rails::Engine
    include Wagons::Wagon

    # Set the required application version.
    app_requirement ">= 0"

    # Add a load path for this specific wagon
    config.autoload_paths += %W[
      #{config.root}/app/abilities
      #{config.root}/app/domain
      #{config.root}/app/jobs
    ]

    config.to_prepare do
      # Add dpsg-specific role rules for beitragspflichtig handling.
      Role.include Dpsg::Role

      # Set after concern include to avoid load-order issues during class loading.
      Group::Bibergruppe::Mitglied.beitragspflichtig = true
      Group::Woelflingsmeute::Woelfling.beitragspflichtig = true
      Group::Jungpfadfindertrupp::Jungpfadfinder.beitragspflichtig = true
      Group::Pfadfindertrupp::Pfadfinder.beitragspflichtig = true
      Group::Roverrunde::Rover.beitragspflichtig = true

      # Add helper methods for fee/beitragspflichtig labels in role select UI.
      RolesHelper.include Dpsg::RolesHelper
    end

    initializer "dpsg.add_settings" do |_app|
      Settings.add_source!(File.join(paths["config"].existent, "settings.yml"))
      Settings.reload!
    end

    initializer "dpsg.add_inflections" do |_app|
      ActiveSupport::Inflector.inflections do |inflect|
        # inflect.irregular "census", "censuses"
      end
    end

    private

    def seed_fixtures
      fixtures = root.join("db", "seeds")
      ENV["NO_ENV"] ? [fixtures] : [fixtures, File.join(fixtures, Rails.env)] # rubocop:disable Rails/EnvironmentVariableAccess -- This is initialization
    end
  end
end
