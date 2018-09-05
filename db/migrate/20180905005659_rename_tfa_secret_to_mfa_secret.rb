# frozen_string_literal: true

class RenameTfaSecretToMfaSecret < ActiveRecord::Migration[5.2]
  def change
    rename_column :users, :tfa_secret, :mfa_secret
  end
end
