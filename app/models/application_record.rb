class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  FOLLOWER_COLOR = ENV["DATABASE_FOLLOWER_COLOR"].to_s.upcase
  FOLLOWER_URL = ENV["HEROKU_POSTGRESQL_#{FOLLOWER_COLOR}_URL"]

  if FOLLOWER_URL.present?
    connects_to database: {writing: :primary, reading: :follower}
  end

  def self.read_only
    if FOLLOWER_URL.present?
      ActiveRecord::Base.connected_to(role: :reading) do
        # All code in this block will run against the follower database.
        # If a write is attempted, an ActiveRecord::ReadOnlyError will raise.
        yield
      end
    else
      # All code in this block will run against the only configured database.
      # Database roles `primary` and `follower` are not available.
      yield
    end
  end
end
