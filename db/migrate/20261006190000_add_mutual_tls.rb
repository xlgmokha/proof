# frozen_string_literal: true

# RFC 8705: clients that authenticate with a TLS certificate, and access
# tokens bound to one.
class AddMutualTls < ActiveRecord::Migration[8.1]
  def change
    change_table :clients do |t|
      t.string :tls_client_auth_subject_dn
      t.string :tls_client_auth_san_dns
      t.string :tls_client_auth_san_uri
      t.string :tls_client_auth_san_ip
      t.string :tls_client_auth_san_email
      t.boolean :tls_client_certificate_bound_access_tokens, null: false, default: false
    end
    add_column :tokens, :x5t_s256, :string
  end
end
