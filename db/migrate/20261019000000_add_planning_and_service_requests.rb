class AddPlanningAndServiceRequests < ActiveRecord::Migration[7.1]
  def change
    create_table :financial_goals do |t|
      t.references :client, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category, null: false
      t.bigint :target_amount_cents, null: false
      t.string :currency, null: false
      t.date :target_date, null: false
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_check_constraint :financial_goals, "target_amount_cents > 0 AND target_amount_cents <= 1000000000000",
      name: "financial_goal_target_range"

    create_table :goal_contributions do |t|
      t.references :financial_goal, null: false, foreign_key: true
      t.string :external_reference, null: false
      t.bigint :amount_cents, null: false
      t.date :contributed_on, null: false
      t.timestamps
    end
    add_index :goal_contributions, %i[financial_goal_id external_reference], unique: true,
      name: "index_goal_contributions_on_goal_and_reference"
    add_check_constraint :goal_contributions, "amount_cents > 0 AND amount_cents <= 1000000000000",
      name: "goal_contribution_amount_range"

    create_table :service_requests do |t|
      t.references :client, null: false, foreign_key: true
      t.string :subject, null: false
      t.string :category, null: false
      t.string :priority, null: false, default: "normal"
      t.text :description, null: false
      t.string :status, null: false, default: "open"
      t.text :resolution_summary
      t.datetime :resolved_at
      t.timestamps
    end
    add_index :service_requests, %i[client_id status]
  end
end
