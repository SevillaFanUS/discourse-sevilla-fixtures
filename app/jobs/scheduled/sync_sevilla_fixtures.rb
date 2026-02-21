# frozen_string_literal: true

module Jobs
  # Runs on a recurring schedule (every 6 hours by default via mini_scheduler).
  # Delegates all logic to DiscourseSevillaFixtures::FixtureSyncService.
  #
  # You can trigger it manually from the Rails console with:
  #   Jobs::SyncSevillaFixtures.new.execute({})
  class SyncSevillaFixtures < ::Jobs::Scheduled
    # Run every 6 hours (21600 seconds)
    every 6.hours

    def execute(args)
      DiscourseSevillaFixtures::FixtureSyncService.new.run
    end
  end
end
