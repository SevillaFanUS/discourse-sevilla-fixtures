# frozen_string_literal: true

class CreateSevillaFixtures < ActiveRecord::Migration[7.0]
  def change
    create_table :sevilla_fixtures do |t|
      # Surrogate UUID key (separate from PK per project convention)
      t.string  :uuid,             null: false
      # The unique fixture ID from football-data.org
      t.integer :external_id,      null: false
      # Competition name (e.g. "La Liga", "Copa del Rey", "UEFA Europa League")
      t.string  :competition,      null: false, default: ""
      # Home and away team names
      t.string  :home_team,        null: false, default: ""
      t.string  :away_team,        null: false, default: ""
      # Scheduled kickoff in UTC
      t.datetime :kickoff_at,      null: true
      # Match venue
      t.string  :venue,            null: true
      # The Discourse topic ID created for this fixture (nil until posted)
      t.integer :discourse_topic_id, null: true
      # Status from football-data.org (SCHEDULED, LIVE, FINISHED, POSTPONED, etc.)
      t.string  :status,           null: false, default: "SCHEDULED"
      # Season year (e.g. 2024 for the 2024/25 season)
      t.integer :season,           null: false, default: 0

      t.timestamps
    end

    add_index :sevilla_fixtures, :uuid, unique: true
    add_index :sevilla_fixtures, :external_id, unique: true
    add_index :sevilla_fixtures, :discourse_topic_id
    add_index :sevilla_fixtures, :kickoff_at
    add_index :sevilla_fixtures, :status
  end
end
