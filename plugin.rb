# frozen_string_literal: true

# name: discourse-sevilla-fixtures
# about: Automatically creates match thread topics and Events for Sevilla FC fixtures
# version: 1.0.0
# authors: MonchisMen
# url: https://monchismen.com

enabled_site_setting :sevilla_fixtures_enabled

after_initialize do
  require_relative "app/models/sevilla_fixture"
  require_relative "lib/discourse_sevilla_fixtures/football_data_client"
  require_relative "lib/discourse_sevilla_fixtures/fixture_post_builder"
  require_relative "lib/discourse_sevilla_fixtures/fixture_sync_service"
  require_relative "app/jobs/scheduled/sync_sevilla_fixtures"
end
