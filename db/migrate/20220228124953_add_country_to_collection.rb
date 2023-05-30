class AddCountryToCollection < ActiveRecord::Migration[6.1]
  def change
    add_column :collections, :country, :string
  end
end
