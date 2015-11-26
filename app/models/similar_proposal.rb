class SimilarProposal < ActiveRecord::Base
	belongs_to :Proposal

	scope :similar, -> { where(proposals_id: 30) }

end