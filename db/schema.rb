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

ActiveRecord::Schema[8.1].define(version: 2026_10_06_190000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pgcrypto"
  enable_extension "uuid-ossp"

  create_table "audits", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "auditable_id"
    t.string "auditable_type"
    t.string "associated_id"
    t.string "associated_type"
    t.string "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.text "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at"
    t.index ["associated_type", "associated_id"], name: "index_audits_on_associated_type_and_associated_id"
    t.index ["auditable_type", "auditable_id", "version"], name: "index_audits_on_auditable_type_and_auditable_id_and_version"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "index_audits_on_user_id_and_user_type"
  end

  create_table "authorizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "client_id"
    t.string "code", null: false
    t.string "challenge"
    t.integer "challenge_method", default: 0
    t.datetime "expired_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "redirect_uri"
    t.string "scope"
    t.string "resource"
    t.string "dpop_jkt"
    t.jsonb "authorization_details"
    t.index ["client_id"], name: "index_authorizations_on_client_id"
    t.index ["code"], name: "index_authorizations_on_code"
    t.index ["user_id"], name: "index_authorizations_on_user_id"
  end

  create_table "clients", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "redirect_uris", default: [], null: false, array: true
    t.integer "token_endpoint_auth_method", default: 0, null: false
    t.string "logo_uri"
    t.string "jwks_uri"
    t.jsonb "jwks"
    t.text "grant_types", default: ["authorization_code", "refresh_token", "client_credentials", "urn:ietf:params:oauth:grant-type:saml2-bearer", "urn:ietf:params:oauth:grant-type:jwt-bearer"], null: false, array: true
    t.text "response_types", default: ["code"], null: false, array: true
    t.string "scope"
    t.text "contacts", default: [], null: false, array: true
    t.string "client_uri"
    t.string "tos_uri"
    t.string "policy_uri"
    t.string "software_id"
    t.string "software_version"
    t.boolean "require_pushed_authorization_requests", default: false, null: false
    t.boolean "require_signed_request_object", default: false, null: false
    t.string "resources", default: [], null: false, array: true
    t.string "authorization_details_types", default: [], null: false, array: true
    t.string "request_uris", default: [], null: false, array: true
    t.string "tls_client_auth_subject_dn"
    t.string "tls_client_auth_san_dns"
    t.string "tls_client_auth_san_uri"
    t.string "tls_client_auth_san_ip"
    t.string "tls_client_auth_san_email"
    t.boolean "tls_client_certificate_bound_access_tokens", default: false, null: false
  end

  create_table "device_authorizations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.uuid "user_id"
    t.string "device_code_digest", null: false
    t.string "user_code", null: false
    t.string "scope"
    t.string "resource"
    t.integer "status", default: 0, null: false
    t.integer "interval", default: 5, null: false
    t.datetime "last_polled_at"
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_device_authorizations_on_client_id"
    t.index ["device_code_digest"], name: "index_device_authorizations_on_device_code_digest", unique: true
    t.index ["user_code"], name: "index_device_authorizations_on_user_code", unique: true
    t.index ["user_id"], name: "index_device_authorizations_on_user_id"
  end

  create_table "failed_device_attempts", force: :cascade do |t|
    t.string "subject", null: false
    t.datetime "created_at", null: false
    t.index ["created_at"], name: "index_failed_device_attempts_on_created_at"
    t.index ["subject", "created_at"], name: "index_failed_device_attempts_on_subject_and_created_at"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "group_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "group_id", null: false
    t.uuid "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "user_id"], name: "index_group_memberships_on_group_id_and_user_id", unique: true
    t.index ["group_id"], name: "index_group_memberships_on_group_id"
    t.index ["user_id"], name: "index_group_memberships_on_user_id"
  end

  create_table "groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "display_name", null: false
    t.integer "lock_version", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "lower((display_name)::text)", name: "index_groups_on_lower_display_name", unique: true
  end

  create_table "pushed_authorization_requests", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.string "reference", null: false
    t.jsonb "parameters", default: {}, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_pushed_authorization_requests_on_client_id"
    t.index ["reference"], name: "index_pushed_authorization_requests_on_reference", unique: true
  end

  create_table "sessions", id: :serial, force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "subject_type"
    t.uuid "subject_id"
    t.string "audience_type"
    t.uuid "audience_id"
    t.integer "token_type", default: 0
    t.datetime "expired_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "authorization_id"
    t.string "scope"
    t.string "resource"
    t.string "dpop_jkt"
    t.uuid "family_id"
    t.jsonb "act"
    t.jsonb "authorization_details"
    t.string "x5t_s256"
    t.index ["audience_type", "audience_id"], name: "index_tokens_on_audience_type_and_audience_id"
    t.index ["authorization_id"], name: "index_tokens_on_authorization_id"
    t.index ["family_id"], name: "index_tokens_on_family_id"
    t.index ["subject_type", "subject_id"], name: "index_tokens_on_subject_type_and_subject_id"
  end

  create_table "used_assertions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "client_id", null: false
    t.string "jti", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "jti"], name: "index_used_assertions_on_client_id_and_jti", unique: true
    t.index ["client_id"], name: "index_used_assertions_on_client_id"
    t.index ["expires_at"], name: "index_used_assertions_on_expires_at"
  end

  create_table "used_proofs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["digest"], name: "index_used_proofs_on_digest", unique: true
    t.index ["expires_at"], name: "index_used_proofs_on_expires_at"
  end

  create_table "user_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.string "key"
    t.string "ip"
    t.text "user_agent"
    t.datetime "sudo_enabled_at"
    t.datetime "accessed_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_user_sessions_on_key", unique: true
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "lock_version", default: 0, null: false
    t.string "mfa_secret"
    t.string "locale", default: "en", null: false
    t.string "timezone", default: "Etc/UTC", null: false
    t.index ["email"], name: "index_users_on_email"
  end

  add_foreign_key "authorizations", "clients"
  add_foreign_key "authorizations", "users"
  add_foreign_key "device_authorizations", "clients", on_delete: :cascade
  add_foreign_key "device_authorizations", "users", on_delete: :cascade
  add_foreign_key "group_memberships", "groups"
  add_foreign_key "group_memberships", "users"
  add_foreign_key "pushed_authorization_requests", "clients", on_delete: :cascade
  add_foreign_key "used_assertions", "clients", on_delete: :cascade
  add_foreign_key "user_sessions", "users"
end
