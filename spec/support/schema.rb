ActiveRecord::Schema.define do
  self.verbose = false

  create_table "users", force: :cascade do |t|
    t.text "hashed_password"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "clients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "veri_sessions", force: :cascade do |t|
    t.string "hashed_token", null: false
    t.datetime "expires_at", null: false
    t.integer "authenticatable_id", null: false
    t.datetime "last_seen_at", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["hashed_token"], name: "index_veri_sessions_on_hashed_token", unique: true
    t.index ["authenticatable_id"], name: "index_veri_sessions_on_authenticatable_id"
  end

  add_foreign_key "veri_sessions", "users", column: "authenticatable_id"
end
