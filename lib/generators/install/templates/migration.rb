# frozen_string_literal: true

class AddDenylistedToken < ActiveRecord::Migration<%= migration_version %>
  def change
    create_table :denylisted_tokens do |t|
      t.string :jti, null: false
      t.datetime :exp, null: false
    end
    add_index :denylisted_tokens, :jti
  end
end
