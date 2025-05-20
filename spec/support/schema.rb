ActiveRecord::Schema.define do
  self.verbose = false

  create_table "users", force: true do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
