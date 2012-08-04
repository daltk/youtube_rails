class CreateVideos < ActiveRecord::Migration
  def self.up
    create_table :videos do |t|
      t.column :title, :string
      t.column :description, :text
      t.column :hashed_name, :string
      t.column :status_code, :integer, :default => 0
      t.column :created_at, :datetime
    end
  end

  def self.down
    drop_table :videos
  end
end
