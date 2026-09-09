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

ActiveRecord::Schema[8.1].define(version: 2026_09_09_152004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "rental_agreements", force: :cascade do |t|
    t.boolean "contract_approved"
    t.datetime "created_at", null: false
    t.string "customer_email"
    t.string "customer_name"
    t.string "customer_phone"
    t.string "payment_method"
    t.string "payment_status"
    t.date "pickup_date"
    t.string "reference_number"
    t.boolean "send_email_copy"
    t.boolean "special_needs"
    t.text "special_needs_notes"
    t.decimal "total_meters"
    t.decimal "total_price"
    t.datetime "updated_at", null: false
  end

  create_table "storage_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.decimal "meters"
    t.string "registration_number"
    t.bigint "rental_agreement_id", null: false
    t.datetime "updated_at", null: false
    t.index ["rental_agreement_id"], name: "index_storage_items_on_rental_agreement_id"
  end

  add_foreign_key "storage_items", "rental_agreements"
end
