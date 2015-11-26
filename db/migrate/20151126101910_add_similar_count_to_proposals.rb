class AddSimilarCountToProposals < ActiveRecord::Migration
  def change
	add_column :proposals, :similar_count, :integer, default: 0
  end
end
