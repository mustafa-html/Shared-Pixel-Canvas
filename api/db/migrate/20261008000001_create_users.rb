class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :guest_token, limit: 64, null: false
      t.string :display_name, limit: 32, null: false
      t.datetime :last_seen_at, precision: 6, null: false
      t.datetime :created_at, precision: 6, null: false
    end

    add_index :users, :guest_token, unique: true
  end
end
