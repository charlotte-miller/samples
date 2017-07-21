# == Schema Information
#
# Table name: approval_requests
#
#  id               :integer          not null, primary key
#  user_id          :integer          not null
#  post_id          :integer          not null
#  status           :integer          default("0"), not null
#  last_vistited_at :datetime         not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_approval_requests_on_post_id              (post_id)
#  index_approval_requests_on_user_id_and_post_id  (user_id,post_id) UNIQUE
#  index_approval_requests_on_user_id_and_status   (user_id,status)
#

require 'rails_helper'

RSpec.describe ApprovalRequest, :type => :model do
  before(:all) do
    @ministry  = create(:populated_ministry)
    @leader    = @ministry.leaders.first
    @volunteer = @ministry.volunteers.first
    @editor    = @ministry.editors.first
  end

  subject { build(:approval_request) }

  it "builds from factory", :internal do
    expect { create(:approval_request) }.to_not raise_error
  end

  it { should belong_to(:post) }
  it { should belong_to(:user) }

  it 'touches the associated Post' do
    Timecop.travel(2.minutes.ago) { @subject = create(:approval_request) }
    Timecop.freeze do
      @subject.touch
      expect(@subject.updated_at).to eq(@subject.post.updated_at)
    end
  end

  describe '#peers [association]' do
    before(:all) do
      @subject = create(:approval_request)
      @post  = @subject.post
      @peers = 3.times.map { create(:approval_request, post:@post) }
      @not_peer = create(:approval_request)
      @sample_peer = @peers.sample
    end

    it { should have_many(:peers) }

    it 'is an ApprovalRequest' do
      expect(@sample_peer).to be_a ApprovalRequest
    end

    it 'includes all ApprovalRequest for this post_id' do
      @peers.each {|peer| expect(@subject.peers).to include peer}
      expect(@subject.peers).to_not include @not_peer
    end

    it 'should not include self' do
      expect(@subject.peers).to_not include @subject
    end
  end

  describe '#check_for_concensus' do

    before(:each) do
      @author ||= @ministry.volunteers.first
      @post = create(:post, ministry:@ministry, author: @author)
      @approval_requests = @post.approval_requests
      @subject = @approval_requests.first
      @leader1, @leader2, @editor1, @editor2 = @approval_requests
    end

    it 'checks on update' do
      expect(@subject).to receive :check_for_concensus
      @subject.accepted!
    end

    context 'CONCENSUS REACHED' do
      let(:run) { @approval_requests[1..2].map(&:accepted!) }

      it 'publishes the post' do
        run
        expect(@subject.post.published_at).to_not be_nil
      end

      context 'Volunteer post' do
        it 'archives its peers ApprovalRequest' do
          run
          expect(ApprovalRequest.archived.count).to eq(2)
          expect(ApprovalRequest.accepted.count).to eq(3) #includes user
          @approval_requests[1..2].each {|request| expect(ApprovalRequest.accepted).to include request }
        end
      end

      context 'Leader post' do
        before(:all) { @author = @ministry.leaders.first }

        it 'archives its peers ApprovalRequest' do
          @approval_requests.first.accepted!
          expect(ApprovalRequest.archived.count).to eq(1)
          expect(ApprovalRequest.accepted.count).to eq(2) #includes user
          expect(ApprovalRequest.accepted).to include @approval_requests.first
        end
      end

      context 'Editor post' do
        before(:all) { @author = @ministry.editors.first }

        it 'is instantly published' do
          expect(@post.published_at).to_not be_nil
        end
      end
    end

    context 'CONCENSUS REJECTED' do

      it 'archives all pending' do
        @leader1.rejected!
        expect(ApprovalRequest.archived.count).to eq(3)
      end

      it 'preserves other votes' do
        @leader2.accepted!
        @leader1.rejected!
        expect(ApprovalRequest.accepted.count).to eq(2) #includes user
        expect(ApprovalRequest.archived.count).to eq(2)
      end

      it 'touches post.rejected_at' do
        expect(@post.rejected_at).to be_nil
        @leader1.rejected!
        expect(@post.reload.rejected_at).to_not be_nil
      end
    end
  end

  describe '#unread_comments' do
    before(:each) do
      @author ||= @ministry.volunteers.first
      @post = create(:post, ministry:@ministry, author: @author)
      @approval_requests = @post.approval_requests
      @subject = @approval_requests.first
      # @leader1, @leader2, @editor1, @editor2 = @approval_requests
      @comments = @subject.add_comment create(:comment, commentable:@subject, user:@author)
    end

    it 'returns comments that were created after last_vistited_at' do
      expect(@subject.unread_comments).to_not be_empty
      expect(@subject.unread_comments).to eq(@comments)
      @subject.touch(:last_vistited_at)
      expect(@subject.unread_comments.reload).to be_empty
    end
  end

  describe '#add_a_comment(text)' do
    before(:each) do
      @author ||= @ministry.volunteers.first
      @post = create(:post, ministry:@ministry, author: @author)
      @approval_requests = @post.approval_requests
    end
    subject { @approval_requests.first }
    let(:run!) {
      subject.add_a_comment 'Foo and bar are wrong... Baz is right' }


    it 'creates a comment' do
      expect { run! }.to change(subject.comment_threads, :count).by(1)
    end

    it 'associates the comment with the @approval_requests and @approval_requests.user' do
      comment = run!
      expect(comment.commentable).to eq(subject)
      expect(comment.author).to eq(subject.user)
    end

    it 'returns the created comment' do
      expect(run!).to be_a Comment
    end
  end

  describe '#current_concensus' do
    before(:each) do
      @post = create(:post, author:@volunteer, ministry:@ministry)
      @subject = ApprovalRequest.where(post:@post, user:@volunteer).first
    end

    it "returns each included group as the key" do
      expect(@subject.current_concensus.keys).to eq(%w{VOLUNTEER LEADER EDITOR})
    end

    it 'does not include empty groups (less involved)' do
      post    = create(:post, author:@leader, ministry:@ministry)
      subject = ApprovalRequest.where(post:post, user:@leader).first
      expect(subject.current_concensus.keys).not_to include('VOLUNTEER')
      expect(subject.current_concensus.keys).to     include('LEADER')
      expect(subject.current_concensus.keys).to     include('EDITOR')
    end

    it 'takes only 1 vote to decide for a group' do
      leader = @ministry.leaders.sample
      editor = @ministry.editors.sample

      expect(@subject.current_concensus['LEADER']).to eql 'undecided'
      ApprovalRequest.where(post:@post, user:leader).first.accepted!
      expect(@subject.reload.current_concensus['LEADER']).to eql 'accepted'

      expect(@subject.current_concensus['EDITOR']).to eql 'undecided'
      ApprovalRequest.where(post:@post, user:editor).first.rejected!
      expect(@subject.reload.current_concensus['EDITOR']).to eql 'rejected'
    end

    it '[optionally] marks the current_user as "AUTHOR"' do
      expect(@subject.current_concensus(:mark_author).keys).to eq(%w{AUTHOR LEADER EDITOR})

      post    = create(:post, author:@leader, ministry:@ministry)
      subject = ApprovalRequest.where(post:post, user:@leader).first
      expect(subject.current_concensus(:mark_author).keys).to eq(%w{AUTHOR EDITOR})
    end
  end

  describe '#send_notification' do
    it 'sends an email' do
      subject = build_stubbed(:approval_request)
      expect(ApprovalRequestMailer).to receive(:open_approval_request).with({:klass=>"ApprovalRequest", :id=>subject.id}).and_call_original
      subject.bypass.send_notification
    end
  end
end
