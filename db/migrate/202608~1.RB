# frozen_string_literal: true

class AddScoresToSevillaFixtures < ActiveRecord::Migration[7.0]
  def change
    # Final score, filled in once the match is played.
    add_column :sevilla_fixtures, :home_score, :integer, null: true
    add_column :sevilla_fixtures, :away_score, :integer, null: true

    # Set once the result has been posted into the match thread, so a
    # result is never posted twice even if the job runs repeatedly.
    add_column :sevilla_fixtures, :result_posted_at, :datetime, null: true

    add_index :sevilla_fixtures, :result_posted_at
  end
end
