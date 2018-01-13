class AddLockVersionToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :lock_version, :bigint, default: 0, null: false
  end
end
