# frozen_string_literal: true

class AlterUsersMakeEmailNotNull < ActiveRecord::Migration[5.2]
  def up
    change_column :users, :email, :string, null: false
    add_index :users, :email
  end

  def down
    change_column :users, :email, :string
    remove_index :users, :email
  end
end
