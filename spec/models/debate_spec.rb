require 'rails_helper'

describe Debate do
  let(:debate) { build(:debate) }

  it "should be valid" do
    expect(debate).to be_valid
  end

  it "should not be valid without an author" do
    debate.author = nil
    expect(debate).to_not be_valid
  end

  describe "#title" do
    it "should not be valid without a title" do
      debate.title = nil
      expect(debate).to_not be_valid
    end

    it "should not be valid when very short" do
      debate.title = "abc"
      expect(debate).to_not be_valid
    end

    it "should not be valid when very long" do
      debate.title = "a" * 81
      expect(debate).to_not be_valid
    end
  end

  describe "#description" do
    it "should not be valid without a description" do
      debate.description = nil
      expect(debate).to_not be_valid
    end

    it "should be sanitized" do
      debate.description = "<script>alert('danger');</script>"
      debate.valid?
      expect(debate.description).to eq("alert('danger');")
    end

    it "should be html_safe" do
      debate.description = "<script>alert('danger');</script>"
      expect(debate.description).to be_html_safe
    end

    it "should not be valid when very short" do
      debate.description = "abc"
      expect(debate).to_not be_valid
    end

    it "should not be valid when very long" do
      debate.description = "a" * 6001
      expect(debate).to_not be_valid
    end
  end

  describe "#tag_list" do
    it "should sanitize the tag list" do
      debate.tag_list = "user_id=1"
      debate.valid?
      expect(debate.tag_list).to eq(['user_id1'])
    end

    it "should not be valid with a tag list of more than 6 elements" do
      debate.tag_list = ["Hacienda", "Economía", "Medio Ambiente", "Corrupción", "Fiestas populares", "Prensa", "Huelgas"]
      expect(debate).to_not be_valid
    end

    it "should be valid with a tag list of  6 elements" do
      debate.tag_list = ["Hacienda", "Economía", "Medio Ambiente", "Corrupción", "Fiestas populares", "Prensa"]
      expect(debate).to be_valid
    end
  end

  it "should not be valid without accepting terms of service" do
    debate.terms_of_service = nil
    expect(debate).to_not be_valid
  end

  describe "#editable?" do
    let(:debate) { create(:debate) }
    before(:each) { Setting.find_by(key: "max_votes_for_debate_edit").update(value: 3) }

    it "should be true if debate has no votes yet" do
      expect(debate.total_votes).to eq(0)
      expect(debate.editable?).to be true
    end

    it "should be true if debate has less than limit votes" do
      create_list(:vote, 2, votable: debate)
      expect(debate.total_votes).to eq(2)
      expect(debate.editable?).to be true
    end

    it "should be false if debate has more than limit votes" do
      create_list(:vote, 4, votable: debate)
      expect(debate.total_votes).to eq(4)
      expect(debate.editable?).to be false
    end
  end

  describe "#editable_by?" do
    let(:debate) { create(:debate) }
    before(:each) { Setting.find_by(key: "max_votes_for_debate_edit").update(value: 1) }

    it "should be true if user is the author and debate is editable" do
      expect(debate.editable_by?(debate.author)).to be true
    end

    it "should be false if debate is not editable" do
      create_list(:vote, 2, votable: debate)
      expect(debate.editable_by?(debate.author)).to be false
    end

    it "should be false if user is not the author" do
      expect(debate.editable_by?(create(:user))).to be false
    end
  end

  describe "#votable_by?" do
    let(:debate) { create(:debate) }

    before(:each) do
      Setting.find_by(key: "max_ratio_anon_votes_on_debates").update(value: 50)
    end

    it "should be true for level two verified users" do
      user = create(:user, residence_verified_at: Time.now, confirmed_phone: "666333111")
      expect(debate.votable_by?(user)).to be true
    end

    it "should be true for level three verified users" do
      user = create(:user, verified_at: Time.now)
      expect(debate.votable_by?(user)).to be true
    end

    it "should be true for anonymous users if allowed anonymous votes" do
      debate.update(cached_anonymous_votes_total: 420, cached_votes_total: 1000)
      user = create(:user)
      expect(debate.votable_by?(user)).to be true
    end

    it "should be true for anonymous users if less than 100 votes" do
      debate.update(cached_anonymous_votes_total: 90, cached_votes_total: 92)
      user = create(:user)
      expect(debate.votable_by?(user)).to be true
    end

    it "should be false for anonymous users if too many anonymous votes" do
      debate.update(cached_anonymous_votes_total: 520, cached_votes_total: 1000)
      user = create(:user)
      expect(debate.votable_by?(user)).to be false
    end
  end

  describe "#register_vote" do
    let(:debate) { create(:debate) }

    before(:each) do
      Setting.find_by(key: "max_ratio_anon_votes_on_debates").update(value: 50)
    end

    describe "from level two verified users" do
      it "should register vote" do
        user = create(:user, residence_verified_at: Time.now, confirmed_phone: "666333111")
        expect {debate.register_vote(user, 'yes')}.to change{debate.reload.votes_for.size}.by(1)
      end

      it "should not increase anonymous votes counter " do
        user = create(:user, residence_verified_at: Time.now, confirmed_phone: "666333111")
        expect {debate.register_vote(user, 'yes')}.to_not change{debate.reload.cached_anonymous_votes_total}
      end
    end

    describe "from level three verified users" do
      it "should register vote" do
        user = create(:user, verified_at: Time.now)
        expect {debate.register_vote(user, 'yes')}.to change{debate.reload.votes_for.size}.by(1)
      end

      it "should not increase anonymous votes counter " do
        user = create(:user, verified_at: Time.now)
        expect {debate.register_vote(user, 'yes')}.to_not change{debate.reload.cached_anonymous_votes_total}
      end
    end

    describe "from anonymous users when anonymous votes are allowed" do
      before(:each) {debate.update(cached_anonymous_votes_total: 42, cached_votes_total: 100)}

      it "should register vote " do
        user = create(:user)
        expect {debate.register_vote(user, 'yes')}.to change {debate.reload.votes_for.size}.by(1)
      end

      it "should increase anonymous votes counter " do
        user = create(:user)
        expect {debate.register_vote(user, 'yes')}.to change {debate.reload.cached_anonymous_votes_total}.by(1)
      end
    end

    describe "from anonymous users when there are too many anonymous votes" do
      before(:each) {debate.update(cached_anonymous_votes_total: 520, cached_votes_total: 1000)}

      it "should not register vote " do
        user = create(:user)
        expect {debate.register_vote(user, 'yes')}.to_not change {debate.reload.votes_for.size}
      end

      it "should not increase anonymous votes counter " do
        user = create(:user)
        expect {debate.register_vote(user, 'yes')}.to_not change {debate.reload.cached_anonymous_votes_total}
      end
    end
  end

  describe '#anonymous_votes_ratio' do
    it "returns the percentage of anonymous votes of the total votes" do
      debate = create(:debate, cached_anonymous_votes_total: 25, cached_votes_total: 100)
      expect(debate.anonymous_votes_ratio).to eq(25.0)
    end
  end

  describe '#hot_score' do
    let(:now) { Time.now }

    it "increases for newer debates" do
      old = create(:debate, :with_hot_score, created_at: now - 1.day)
      new = create(:debate, :with_hot_score, created_at: now)
      expect(new.hot_score).to be > old.hot_score
    end

    it "increases for debates with more comments" do
      more_comments = create(:debate, :with_hot_score, created_at: now, comments_count: 25)
      less_comments = create(:debate, :with_hot_score, created_at: now, comments_count: 1)
      expect(more_comments.hot_score).to be > less_comments.hot_score
    end

    it "increases for debates with more positive votes" do
      more_likes = create(:debate, :with_hot_score, created_at: now, cached_votes_total: 10, cached_votes_up: 5)
      less_likes = create(:debate, :with_hot_score, created_at: now, cached_votes_total: 10, cached_votes_up: 1)
      expect(more_likes.hot_score).to be > less_likes.hot_score
    end

    it "increases for debates with more confidence" do
      more_confidence = create(:debate, :with_hot_score, created_at: now, cached_votes_total: 1000, cached_votes_up: 700)
      less_confidence = create(:debate, :with_hot_score, created_at: now, cached_votes_total: 10, cached_votes_up: 9)
      expect(more_confidence.hot_score).to be > less_confidence.hot_score
    end

    it "decays in older debates, even if they have more votes" do
      older_more_voted = create(:debate, :with_hot_score, created_at: now - 2.days, cached_votes_total: 1000, cached_votes_up: 900)
      new_less_voted   = create(:debate, :with_hot_score, created_at: now, cached_votes_total: 10, cached_votes_up: 9)
      expect(new_less_voted.hot_score).to be > older_more_voted.hot_score
    end

    describe 'actions which affect it' do
      let(:debate) { create(:debate, :with_hot_score) }

      it "increases with likes" do
        previous = debate.hot_score
        5.times { debate.register_vote(create(:user), true) }
        expect(previous).to be < debate.hot_score
      end

      it "decreases with dislikes" do
        debate.register_vote(create(:user), true)
        previous = debate.hot_score
        3.times { debate.register_vote(create(:user), false) }
        expect(previous).to be > debate.hot_score
      end

      it "increases with comments" do
        previous = debate.hot_score
        25.times{ Comment.create(user: create(:user), commentable: debate, body: 'foobarbaz') }
        expect(previous).to be < debate.reload.hot_score
      end
    end
  end

  describe "#confidence_score" do

    it "takes into account percentage of total votes and total_positive and total negative votes" do
      debate = create(:debate, :with_confidence_score, cached_votes_up: 100, cached_votes_score: 100, cached_votes_total: 100)
      expect(debate.confidence_score).to eq(10000)

      debate = create(:debate, :with_confidence_score, cached_votes_up: 0, cached_votes_total: 100)
      expect(debate.confidence_score).to eq(0)

      debate = create(:debate, :with_confidence_score, cached_votes_up: 75, cached_votes_total: 100)
      expect(debate.confidence_score).to eq(3750)

      debate = create(:debate, :with_confidence_score, cached_votes_up: 750, cached_votes_total: 1000)
      expect(debate.confidence_score).to eq(37500)

      debate = create(:debate, :with_confidence_score, cached_votes_up: 10, cached_votes_total: 100)
      expect(debate.confidence_score).to eq(-800)
    end

    describe 'actions which affect it' do
      let(:debate) { create(:debate, :with_confidence_score) }

      it "increases with like" do
        previous = debate.confidence_score
        5.times { debate.register_vote(create(:user), true) }
        expect(previous).to be < debate.confidence_score
      end

      it "decreases with dislikes" do
        debate.register_vote(create(:user), true)
        previous = debate.confidence_score
        3.times { debate.register_vote(create(:user), false) }
        expect(previous).to be > debate.confidence_score
      end
    end

  end

  describe "cache" do
    let(:debate) { create(:debate) }

    it "should expire cache when it has a new comment" do
      expect { create(:comment, commentable: debate) }
      .to change { debate.updated_at }
    end

    it "should expire cache when it has a new vote" do
      expect { create(:vote, votable: debate) }
      .to change { debate.updated_at }
    end

    it "should expire cache when it has a new flag" do
      expect { create(:flag, flaggable: debate) }
      .to change { debate.reload.updated_at }
    end

    it "should expire cache when it has a new tag" do
      expect { debate.update(tag_list: "new tag") }
      .to change { debate.updated_at }
    end

    it "should expire cache when hidden" do
      expect { debate.hide }
      .to change { debate.updated_at }
    end

    it "should expire cache when the author is hidden" do
      expect { debate.author.hide }
      .to change { [debate.reload.updated_at, debate.author.updated_at] }
    end

    it "should expire cache when the author is erased" do
      expect { debate.author.erase }
      .to change { [debate.reload.updated_at, debate.author.updated_at] }
    end

    it "should expire cache when its author changes" do
      expect { debate.author.update(username: "Eva") }
      .to change { [debate.reload.updated_at, debate.author.updated_at] }
    end

    it "should expire cache when the author's organization get verified" do
      create(:organization, user: debate.author)
      expect { debate.author.organization.verify }
      .to change { [debate.reload.updated_at, debate.author.updated_at] }
    end
  end

  describe "custom tag counters when hiding/restoring" do
    it "decreases the tag counter when hiden, and increases it when restored" do
      debate = create(:debate, tag_list: "foo")
      tag = ActsAsTaggableOn::Tag.where(name: 'foo').first
      expect(tag.debates_count).to eq(1)

      debate.hide
      expect(tag.reload.debates_count).to eq(0)

      debate.restore
      expect(tag.reload.debates_count).to eq(1)
    end
  end

  describe "conflictive debates" do

    it "should return true when it has more than 1 flag for 5 positive votes" do
      debate.update(cached_votes_up: 4)
      debate.update(flags_count: 1)
      expect(debate).to be_conflictive

      debate.update(cached_votes_up: 9)
      debate.update(flags_count: 2)
      expect(debate).to be_conflictive

      debate.update(cached_votes_up: 14)
      debate.update(flags_count: 3)
      expect(debate).to be_conflictive

      debate.update(cached_votes_up: 2)
      debate.update(flags_count: 20)
      expect(debate).to be_conflictive
    end

    it "should return false when it has less than or equal to 1 flag for 5 positive votes" do
      debate.update(cached_votes_up: 5)
      debate.update(flags_count: 1)
      expect(debate).to_not be_conflictive

      debate.update(cached_votes_up: 10)
      debate.update(flags_count: 2)
      expect(debate).to_not be_conflictive

      debate.update(cached_votes_up: 100)
      debate.update(flags_count: 2)
      expect(debate).to_not be_conflictive
    end

    it "should return false when it has no flags" do
      debate.update(flags_count: 0)
      expect(debate).to_not be_conflictive
    end

    it "should return false when it has not votes up" do
      debate.update(cached_votes_up: 0)
      expect(debate).to_not be_conflictive
    end

  end

  describe "search" do

    context "attributes" do

      xit "searches by title" do
        debate = create(:debate, title: 'save the world')
        results = Debate.search('save the world')
        expect(results).to eq([debate])
      end

      xit "searches by description" do
        debate = create(:debate, description: 'in order to save the world one must think about...')
        results = Debate.search('one must think')
        expect(results).to eq([debate])
      end

    end

    context "stemming" do

      xit "searches word stems" do
        debate = create(:debate, title: 'limpiar')

        results = Debate.search('limpiará')
        expect(results).to eq([debate])

        results = Debate.search('limpiémos')
        expect(results).to eq([debate])

        results = Debate.search('limpió')
        expect(results).to eq([debate])
      end

    end

    context "accents" do

      xit "searches with accents" do
        debate = create(:debate, title: 'difusión')

        results = Debate.search('difusion')
        expect(results).to eq([debate])

        debate2 = create(:debate, title: 'estadisticas')
        results = Debate.search('estadísticas')
        expect(results).to eq([debate2])
      end

    end

    context "case" do

      xit "searches case insensite" do
        debate = create(:debate, title: 'SHOUT')

        results = Debate.search('shout')
        expect(results).to eq([debate])

        debate2 = create(:debate, title: "scream")
        results = Debate.search("SCREAM")
        expect(results).to eq([debate2])
      end

    end

    context "typos" do

      xit "searches with typos" do
        debate = create(:debate, title: 'difusión')

        results = Debate.search('difuon')
        expect(results).to eq([debate])

        debate2 = create(:debate, title: 'desarrollo')
        results = Debate.search('desarolo')
        expect(results).to eq([debate2])
      end

    end

    context "order" do

      xit "orders by weight" do
        debate_description = create(:debate,  description: 'stop corruption')
        debate_title       = create(:debate,  title:       'stop corruption')

        results = Debate.search('stop corruption')

        expect(results.first).to eq(debate_title)
        expect(results.second).to eq(debate_description)
      end

      xit "orders by weight and then votes" do
        title_some_votes    = create(:debate, title: 'stop corruption', cached_votes_up: 5)
        title_least_voted   = create(:debate, title: 'stop corruption', cached_votes_up: 2)
        title_most_voted    = create(:debate, title: 'stop corruption', cached_votes_up: 10)
        description_most_voted  = create(:debate, description: 'stop corruption', cached_votes_up: 10)

        results = Debate.search('stop corruption')

        expect(results.first).to eq(title_most_voted)
        expect(results.second).to eq(description_most_voted)
        expect(results.third).to eq(title_some_votes)
        expect(results.fourth).to eq(title_least_voted)
      end

      xit "orders by weight and then votes and then created_at" do
        newest = create(:debate, title: 'stop corruption', cached_votes_up: 5, created_at: Time.now)
        oldest = create(:debate, title: 'stop corruption', cached_votes_up: 5, created_at: 1.month.ago)
        old    = create(:debate, title: 'stop corruption', cached_votes_up: 5, created_at: 1.week.ago)

        results = Debate.search('stop corruption')

        expect(results.first).to eq(newest)
        expect(results.second).to eq(old)
        expect(results.third).to eq(oldest)
      end

    end

    context "tags" do

      xit "searches by tags" do
        debate = create(:debate, tag_list: 'Latina')

        results = Debate.search('Latina')
        expect(results.first).to eq(debate)
      end

    end

    context "no results" do

      xit "no words match" do
        debate = create(:debate, title: 'save world')

        results = Debate.search('destroy planet')
        expect(results).to eq([])
      end

      xit "too many typos" do
        debate = create(:debate, title: 'fantastic')

        results = Debate.search('frantac')
        expect(results).to eq([])
      end

      xit "too much stemming" do
        debate = create(:debate, title: 'reloj')

        results = Debate.search('superrelojimetro')
        expect(results).to eq([])
      end

      xit "empty" do
        debate = create(:debate, title: 'great')

        results = Debate.search('')
        expect(results).to eq([])
      end

    end

  end

end
