class AddThings < ActiveRecord::Migration[6.1]
  def change
    create_table :things, force: :cascade do |t|
      t.timestamps null: false
      t.string :name
    end
  end
end
