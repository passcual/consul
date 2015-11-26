class CreateSimilarProposal < ActiveRecord::Migration
  def change
    create_table :similar_proposals do |t|
      t.integer  "proposals_id"
      t.integer  "similar_proposals_id"
    end
  end
end
