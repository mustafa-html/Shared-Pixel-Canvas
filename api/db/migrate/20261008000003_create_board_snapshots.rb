class CreateBoardSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :board_snapshots do |t|
      # The last sequence number the snapshot includes.
      t.bigint :seq, null: false
      t.binary :data, limit: 16.megabytes - 1, null: false
      t.datetime :created_at, precision: 6, null: false
    end

    add_index :board_snapshots, :seq
  end
end
