class User < ApplicationRecord
  has_many :pixel_events, dependent: :restrict_with_exception

  validates :guest_token, presence: true, uniqueness: true
  validates :display_name, presence: true

  def self.create_guest!
    create!(
      guest_token: SecureRandom.hex(32),
      display_name: "Guest #{SecureRandom.random_number(1000..9999)}",
      last_seen_at: Time.current
    )
  end

  def seen!
    return if last_seen_at > 5.minutes.ago

    update_column(:last_seen_at, Time.current)
  end
end
