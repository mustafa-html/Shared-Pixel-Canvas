# Append-only: one row per accepted placement, never updated or deleted.
class CreatePixelEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :pixel_events do |t|
      # Assigned by Redis. Defines the order a rebuild replays events in.
      t.bigint :seq, null: false
      t.bigint :user_id, null: false
      t.integer :x, limit: 2, unsigned: true, null: false
      t.integer :y, limit: 2, unsigned: true, null: false
      t.integer :color, limit: 1, unsigned: true, null: false
      t.datetime :created_at, precision: 6, null: false
    end

    # Also what makes the retry job idempotent.
    add_index :pixel_events, :seq, unique: true
    # "Who placed this pixel?"
    add_index :pixel_events, %i[x y seq]
    # Per-user statistics.
    add_index :pixel_events, %i[user_id created_at]

    add_foreign_key :pixel_events, :users
  end
end
