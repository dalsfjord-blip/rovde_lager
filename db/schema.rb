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

ActiveRecord::Schema[8.1].define(version: 2026_10_01_091000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "document_number_sequences", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_value", default: 9999, null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_document_number_sequences_on_name", unique: true
  end

  create_table "harbor_rentals", force: :cascade do |t|
    t.string "billing_company_name", null: false
    t.string "billing_email", null: false
    t.string "billing_organization_number", null: false
    t.datetime "created_at", null: false
    t.integer "days", null: false
    t.date "invoice_due_date"
    t.string "invoice_number"
    t.datetime "invoice_sent_at"
    t.string "payment_status", null: false
    t.string "reference_number"
    t.decimal "total_price", precision: 12, scale: 2, null: false
    t.decimal "total_price_with_vat", precision: 12, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.decimal "vat_amount", precision: 12, scale: 2, null: false
    t.index ["invoice_number"], name: "index_harbor_rentals_on_invoice_number", unique: true
    t.index ["reference_number"], name: "index_harbor_rentals_on_reference_number", unique: true
    t.index ["user_id"], name: "index_harbor_rentals_on_user_id"
  end

  create_table "power_office_sync_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "detail"
    t.bigint "rental_agreement_id", null: false
    t.string "status"
    t.string "step"
    t.datetime "updated_at", null: false
    t.index ["rental_agreement_id"], name: "index_power_office_sync_logs_on_rental_agreement_id"
  end

  create_table "rental_agreements", force: :cascade do |t|
    t.string "billing_company_name"
    t.string "billing_email"
    t.string "billing_organization_number"
    t.boolean "business_customer", default: false, null: false
    t.boolean "contract_approved"
    t.datetime "created_at", null: false
    t.string "customer_email"
    t.string "customer_name"
    t.string "customer_phone"
    t.date "invoice_due_date"
    t.string "invoice_number"
    t.datetime "invoice_sent_at"
    t.datetime "paid_at"
    t.string "payment_method"
    t.string "payment_status"
    t.date "pickup_date"
    t.string "power_office_customer_id"
    t.string "power_office_invoice_id"
    t.string "power_office_invoice_number"
    t.string "power_office_sales_order_id"
    t.text "power_office_sync_error"
    t.string "power_office_sync_status"
    t.datetime "power_office_synced_at"
    t.datetime "receipt_sent_at"
    t.string "reference_number"
    t.boolean "send_email_copy"
    t.boolean "special_needs"
    t.text "special_needs_notes"
    t.decimal "total_meters"
    t.decimal "total_price"
    t.decimal "total_price_with_vat", precision: 12, scale: 2
    t.datetime "updated_at", null: false
    t.decimal "vat_amount", precision: 12, scale: 2
    t.datetime "vipps_payment_created_at"
    t.text "vipps_payment_url"
    t.string "vipps_reference"
    t.index ["invoice_number"], name: "index_rental_agreements_on_invoice_number", unique: true
    t.index ["power_office_invoice_number"], name: "index_rental_agreements_on_power_office_invoice_number", unique: true
    t.index ["vipps_reference"], name: "index_rental_agreements_on_vipps_reference", unique: true
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

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "phone_number"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true, where: "(phone_number IS NOT NULL)"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "harbor_rentals", "users"
  add_foreign_key "power_office_sync_logs", "rental_agreements"
  add_foreign_key "storage_items", "rental_agreements"
end
