# frozen_string_literal: true

class AddTfaSecretToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :tfa_secret, :string
  end
end
