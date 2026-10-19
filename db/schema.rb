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

ActiveRecord::Schema[7.1].define(version: 2026_10_19_000000) do
  create_table "clients", force: :cascade do |t|
    t.string "external_reference", null: false
    t.string "display_name", null: false
    t.string "risk_profile", null: false
    t.string "onboarding_status", default: "pending", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_reference"], name: "index_clients_on_external_reference", unique: true
  end

  create_table "financial_goals", force: :cascade do |t|
    t.integer "client_id", null: false
    t.string "name", null: false
    t.string "category", null: false
    t.bigint "target_amount_cents", null: false
    t.string "currency", null: false
    t.date "target_date", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_financial_goals_on_client_id"
    t.check_constraint "target_amount_cents > 0 AND target_amount_cents <= 1000000000000", name: "financial_goal_target_range"
  end

  create_table "goal_contributions", force: :cascade do |t|
    t.integer "financial_goal_id", null: false
    t.string "external_reference", null: false
    t.bigint "amount_cents", null: false
    t.date "contributed_on", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["financial_goal_id", "external_reference"], name: "index_goal_contributions_on_goal_and_reference", unique: true
    t.index ["financial_goal_id"], name: "index_goal_contributions_on_financial_goal_id"
    t.check_constraint "amount_cents > 0 AND amount_cents <= 1000000000000", name: "goal_contribution_amount_range"
  end

  create_table "service_requests", force: :cascade do |t|
    t.integer "client_id", null: false
    t.string "subject", null: false
    t.string "category", null: false
    t.string "priority", default: "normal", null: false
    t.text "description", null: false
    t.string "status", default: "open", null: false
    t.text "resolution_summary"
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "status"], name: "index_service_requests_on_client_id_and_status"
    t.index ["client_id"], name: "index_service_requests_on_client_id"
  end

  add_foreign_key "financial_goals", "clients"
  add_foreign_key "goal_contributions", "financial_goals"
  add_foreign_key "service_requests", "clients"
end
