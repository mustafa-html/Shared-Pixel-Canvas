# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_10_08_000003) do
  create_table "board_snapshots", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "seq", null: false
    t.binary "data", size: :medium, null: false
    t.datetime "created_at", null: false
    t.index ["seq"], name: "index_board_snapshots_on_seq"
  end

  create_table "pixel_events", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "seq", null: false
    t.bigint "user_id", null: false
    t.integer "x", limit: 2, null: false, unsigned: true
    t.integer "y", limit: 2, null: false, unsigned: true
    t.integer "color", limit: 1, null: false, unsigned: true
    t.datetime "created_at", null: false
    t.index ["seq"], name: "index_pixel_events_on_seq", unique: true
    t.index ["user_id", "created_at"], name: "index_pixel_events_on_user_id_and_created_at"
    t.index ["x", "y", "seq"], name: "index_pixel_events_on_x_and_y_and_seq"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "guest_token", limit: 64, null: false
    t.string "display_name", limit: 32, null: false
    t.datetime "last_seen_at", null: false
    t.datetime "created_at", null: false
    t.index ["guest_token"], name: "index_users_on_guest_token", unique: true
  end

  add_foreign_key "pixel_events", "users"
end
