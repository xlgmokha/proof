# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2018_10_20_161349) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "audits", force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
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

  create_table "authorizations", force: :cascade do |t|
    t.bigint "user_id"
    t.bigint "client_id"
    t.string "code", null: false
    t.string "challenge"
    t.integer "challenge_method", default: 0
    t.datetime "expired_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_authorizations_on_client_id"
    t.index ["code"], name: "index_authorizations_on_code"
    t.index ["user_id"], name: "index_authorizations_on_user_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "uuid", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "redirect_uris", default: [], null: false, array: true
    t.integer "token_endpoint_auth_method", default: 0, null: false
    t.string "logo_uri"
    t.string "jwks_uri"
    t.index ["uuid"], name: "index_clients_on_uuid"
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

  create_table "sessions", id: :serial, force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "tokens", force: :cascade do |t|
    t.string "uuid"
    t.bigint "authorization_id"
    t.string "subject_type"
    t.bigint "subject_id"
    t.string "audience_type"
    t.bigint "audience_id"
    t.integer "token_type", default: 0
    t.datetime "expired_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["audience_type", "audience_id"], name: "index_tokens_on_audience_type_and_audience_id"
    t.index ["authorization_id"], name: "index_tokens_on_authorization_id"
    t.index ["subject_type", "subject_id"], name: "index_tokens_on_subject_type_and_subject_id"
    t.index ["uuid"], name: "index_tokens_on_uuid", unique: true
  end

  create_table "user_sessions", force: :cascade do |t|
    t.bigint "user_id"
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

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "uuid", null: false
    t.string "password_digest"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "lock_version", default: 0, null: false
    t.string "mfa_secret", limit: 16
    t.string "locale", default: "en", null: false
    t.string "timezone", default: "Etc/UTC", null: false
    t.index ["uuid"], name: "index_users_on_uuid"
  end

  add_foreign_key "authorizations", "clients"
  add_foreign_key "authorizations", "users"
  add_foreign_key "user_sessions", "users"
end
