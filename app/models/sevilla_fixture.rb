# frozen_string_literal: true

# Represents a Sevilla FC fixture fetched from football-data.org.
# Tracks whether a Discourse topic/event has been created for it.
class SevillaFixture < ActiveRecord::Base

  # ── Validations ──────────────────────────────────────────────────────────────

  validates :uuid,        presence: true, uniqueness: true
  validates :external_id, presence: true, uniqueness: true
  validates :competition, presence: true
  validates :home_team,   presence: true
  validates :away_team,   presence: true
  validates :status,      presence: true

  # ── Scopes ───────────────────────────────────────────────────────────────────

  # Fixtures that have not yet had a Discourse topic created
  scope :unposted, -> { where(discourse_topic_id: nil) }

  # Fixtures with a confirmed kickoff time within the configured look-ahead window
  scope :upcoming_within, ->(days) {
    where(
      "kickoff_at IS NOT NULL AND kickoff_at BETWEEN ? AND ?",
      Time.current,
      days.days.from_now
    )
  }

  # Fixtures that are still schedulable (not cancelled/postponed)
  scope :schedulable, -> { where(status: %w[SCHEDULED TIMED]) }

  # ── Instance Methods ─────────────────────────────────────────────────────────

  def posted?
    discourse_topic_id.present?
  end

  # Returns true if Sevilla FC is the home side
  def home_game?
    home_team.downcase.include?("sevilla")
  end

  # Human-readable opponent name regardless of home/away
  def opponent
    home_game? ? away_team : home_team
  end

  # Short label: "vs. Atlético Madrid" or "@ Real Betis"
  def matchup_label
    home_game? ? "vs. #{away_team}" : "@ #{home_team}"
  end
end