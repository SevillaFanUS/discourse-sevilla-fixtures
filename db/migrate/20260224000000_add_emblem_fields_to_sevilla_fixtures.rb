# frozen_string_literal: true

class AddEmblemFieldsToSevillaFixtures < ActiveRecord::Migration[7.0]
  def change
    add_column :sevilla_fixtures, :matchday,              :integer, null: true
    add_column :sevilla_fixtures, :competition_emblem,    :string,  null: true
    add_column :sevilla_fixtures, :home_team_crest,       :string,  null: true
    add_column :sevilla_fixtures, :away_team_crest,       :string,  null: true
  end
end