class AddTimezoneLocaleToUsers < ActiveRecord::Migration[5.2]
  def change
    change_table :users do |t|
      t.column :locale, :string, default: 'en', null: false
      t.column :timezone, :string, default: 'Etc/UTC', null: false
    end
  end
end
