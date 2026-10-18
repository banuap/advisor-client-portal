class CreateClients < ActiveRecord::Migration[7.1]
  def change
    create_table :clients do |t|
      t.string :external_reference, null: false
      t.string :display_name, null: false
      t.string :risk_profile, null: false
      t.string :onboarding_status, null: false, default: "pending"
      t.timestamps
    end

    add_index :clients, :external_reference, unique: true
  end
end
