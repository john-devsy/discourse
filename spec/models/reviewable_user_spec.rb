# frozen_string_literal: true

RSpec.describe ReviewableUser, type: :model do
  fab!(:moderator)
  let(:user) do
    user = Fabricate(:user)
    user.activate
    user
  end
  fab!(:admin)

  describe "#actions_for" do
    fab!(:reviewable)

    it "returns correct actions in the pending state" do
      actions = reviewable.actions_for(Guardian.new(moderator))
      expect(actions.has?(:approve_user)).to eq(true)
      expect(actions.has?(:delete_user)).to eq(true)
      expect(actions.has?(:delete_user_block)).to eq(true)
    end

    it "doesn't return anything in the approved state" do
      reviewable.status = Reviewable.statuses[:approved]
      actions = reviewable.actions_for(Guardian.new(moderator))
      expect(actions.has?(:approve_user)).to eq(false)
      expect(actions.has?(:delete_user_block)).to eq(false)
    end

    it "doesn't ask for a rejection reason when deleting a user who was flagged as a possible spammer" do
      reviewable.reviewable_scores.build(user: admin, reason: "suspect_user")

      assert_require_reject_reason(:delete_user, false)
    end

    it "requires a rejection reason to delete a user" do
      assert_require_reject_reason(:delete_user, true)
    end

    it "doesn't ask for a rejection reason when blocking a user who was flagged as a possible spammer" do
      reviewable.reviewable_scores.build(user: admin, reason: "suspect_user")

      assert_require_reject_reason(:delete_user_block, false)
    end

    it "requires a rejection reason to delete and block a user" do
      assert_require_reject_reason(:delete_user_block, true)
    end

    def assert_require_reject_reason(id, expected)
      actions = reviewable.actions_for(Guardian.new(moderator))

      expect(actions.to_a.find { |a| a.server_action.to_sym == id }.require_reject_reason).to eq(
        expected,
      )
    end
  end

  describe "#update_fields" do
    fab!(:moderator)
    fab!(:reviewable)

    it "doesn't raise errors with an empty update" do
      expect(reviewable.update_fields(nil, moderator)).to eq(true)
      expect(reviewable.update_fields({}, moderator)).to eq(true)
    end
  end

  context "when a user is deleted" do
    it "should reject the reviewable" do
      SiteSetting.must_approve_users = true
      Jobs::CreateUserReviewable.new.execute(user_id: user.id)
      reviewable = Reviewable.find_by(target: user)
      expect(reviewable.pending?).to eq(true)

      UserDestroyer.new(Discourse.system_user).destroy(user)
      expect(reviewable.reload.rejected?).to eq(true)
    end
  end

  describe "#perform" do
    fab!(:reviewable)

    context "when approving" do
      it "allows us to approve a user" do
        result = reviewable.perform(moderator, :approve_user)
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.approved?).to eq(true)
        expect(reviewable.target.approved?).to eq(true)
        expect(reviewable.target.approved_by_id).to eq(moderator.id)
        expect(reviewable.target.approved_at).to be_present
        expect(reviewable.version > 0).to eq(true)
      end
    end

    context "when rejecting" do
      it "allows us to reject a user" do
        result = reviewable.perform(moderator, :delete_user, reject_reason: "reject reason")
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.rejected?).to eq(true)

        # Rejecting deletes the user record
        reviewable.reload
        expect(reviewable.target).to be_blank
        expect(reviewable.reject_reason).to eq("reject reason")
        expect(UserHistory.last.context).to eq(I18n.t("user.destroy_reasons.reviewable_reject"))
      end

      it "allows us to reject and block a user" do
        email = reviewable.target.email
        ip = reviewable.target.ip_address

        result = reviewable.perform(moderator, :delete_user_block, reject_reason: "reject reason")
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.rejected?).to eq(true)

        # Rejecting deletes the user record
        reviewable.reload
        expect(reviewable.target).to be_blank
        expect(reviewable.reject_reason).to eq("reject reason")

        expect(ScreenedEmail.should_block?(email)).to eq(true)
        expect(ScreenedIpAddress.should_block?(ip)).to eq(true)
      end

      it "is not sending email to the user about rejection" do
        SiteSetting.must_approve_users = true
        Jobs::CriticalUserEmail.any_instance.expects(:execute).never
        reviewable.perform(moderator, :delete_user_block, reject_reason: "reject reason")
      end

      it "optionally sends email with reject reason" do
        SiteSetting.must_approve_users = true
        Jobs::CriticalUserEmail
          .any_instance
          .expects(:execute)
          .with(
            {
              type: :signup_after_reject,
              user_id: reviewable.target_id,
              reject_reason: "reject reason",
            },
          )
          .once
        reviewable.perform(
          moderator,
          :delete_user_block,
          reject_reason: "reject reason",
          send_email: true,
        )
      end

      it "allows us to reject a user who has posts" do
        Fabricate(:post, user: reviewable.target)
        result = reviewable.perform(moderator, :delete_user)
        expect(result.success?).to eq(true)

        expect(reviewable.pending?).to eq(false)
        expect(reviewable.rejected?).to eq(true)

        # Rejecting deletes the user record
        reviewable.reload
        expect(reviewable.target).to be_present
        expect(reviewable.target.approved).to eq(false)
      end

      it "allows us to reject a user who has been deleted" do
        reviewable.target.destroy!
        reviewable.reload
        result = reviewable.perform(moderator, :delete_user)
        expect(result.success?).to eq(true)
        expect(reviewable.rejected?).to eq(true)
        expect(reviewable.target).to be_blank
      end

      it "silently transitions the reviewable if the user is an admin" do
        reviewable.target.update!(admin: true)

        result = reviewable.perform(moderator, :delete_user)
        expect(reviewable.pending?).to eq(false)
        expect(reviewable.rejected?).to eq(true)

        reviewable.reload
        expect(reviewable.target).to be_present
        expect(reviewable.target.approved).to eq(false)
      end
    end
  end

  describe "changing must_approve_users" do
    it "will approve any existing users" do
      user = Fabricate(:user)
      expect(user).not_to be_approved
      SiteSetting.must_approve_users = true
      expect(user.reload).to be_approved
    end
  end

  describe "when must_approve_users is true" do
    let!(:reviewable) do
      SiteSetting.must_approve_users = true
      Jobs.run_immediately!
      ReviewableUser.find_by(target: user)
    end

    before { Jobs.run_later! }

    it "creates the ReviewableUser for a user, with moderator access" do
      expect(reviewable.reviewable_by_moderator).to eq(true)
    end

    context "with email jobs" do
      it "enqueues a 'signup after approval' email if must_approve_users is true" do
        expect_enqueued_with(job: :critical_user_email, args: { type: :signup_after_approval }) do
          reviewable.perform(admin, :approve_user)
        end
      end

      it "doesn't enqueue a 'signup after approval' email if must_approve_users is false" do
        SiteSetting.must_approve_users = false

        expect_not_enqueued_with(
          job: :critical_user_email,
          args: {
            type: :signup_after_approval,
          },
        ) { reviewable.perform(admin, :approve_user) }
      end
    end

    it "triggers a extensibility event" do
      user && admin # bypass the user_created event
      event =
        DiscourseEvent
          .track_events { ReviewableUser.find_by(target: user).perform(admin, :approve_user) }
          .first

      expect(event[:event_name]).to eq(:user_approved)
      expect(event[:params].first).to eq(user)
    end

    describe "#scrub" do
      it "scrubs the user history record" do
        UserDestroyer.new(admin).destroy(user)
        reviewable.reload

        history = UserHistory.where(action: UserHistory.actions[:delete_user])
        expect(history.count).to eq(1)
        expect(history.first.details).to include("username: #{user.username}")
        expect(history.first.ip_address).not_to be_blank

        reviewable.scrub("reason", Guardian.new(admin))
        reviewable.reload
        history.reload

        expect(history.first.details).to include("User details scrubbed by #{admin.username}")
        expect(history.first.details).to include("reason")
        expect(history.first.details).to include(
          "Timestamp: #{Time.zone.parse(reviewable.payload["scrubbed_at"])}",
        )

        expect(history.first.details).not_to include(user.username)
        expect(history.first.ip_address).to be_blank
      end

      it "doesn't scrub older user history records for the same username" do
        # Create a history record with the same username but older than the reviewable
        UserHistory.create!(
          action: UserHistory.actions[:delete_user],
          details: "id: #{user.id}\nusername: #{user.username}\nname: ",
          created_at: 1.day.ago,
          updated_at: 1.day.ago,
          ip_address: "1.2.3.4",
        )

        UserDestroyer.new(admin).destroy(user)
        reviewable.reload

        history =
          UserHistory.where(action: UserHistory.actions[:delete_user]).order(created_at: :asc)

        expect(history.count).to eq(2)
        expect(history.first.details).to include("username: #{user.username}")
        expect(history.first.ip_address).not_to be_blank
        expect(history.last.details).to include("username: #{user.username}")
        expect(history.last.ip_address).not_to be_blank

        reviewable.scrub("reason", Guardian.new(admin))
        history.reload

        expect(history.first.details).to include(user.username)
        expect(history.first.details).to include("username: #{user.username}")
        expect(history.first.ip_address).not_to be_blank

        expect(history.last.details).to include("User details scrubbed by #{admin.username}")
        expect(history.last.details).to include("reason")
        expect(history.last.details).to include(
          "Timestamp: #{Time.zone.parse(reviewable.payload["scrubbed_at"])}",
        )
        expect(history.last.details).not_to include(user.username)
        expect(history.last.ip_address).to be_blank
      end

      it "replaces the reviewable payload with scrubbed details" do
        expect(reviewable.payload).to be_present
        expect(reviewable.payload["username"]).to eq(user.username)
        expect(reviewable.payload["email"]).to eq(user.email)
        expect(reviewable.payload["name"]).to eq(user.name)

        expect(reviewable.payload["scrubbed_by"]).to be_blank
        expect(reviewable.payload["scrubbed_reason"]).to be_blank
        expect(reviewable.payload["scrubbed_at"]).to be_blank

        reviewable.scrub("reason", Guardian.new(admin))
        reviewable.reload

        expect(reviewable.payload["scrubbed_by"]).to eq(admin.username)
        expect(reviewable.payload["scrubbed_reason"]).to eq("reason")
        expect(reviewable.payload["scrubbed_at"]).to be_present

        expect(reviewable.payload["username"]).to be_blank
        expect(reviewable.payload["email"]).to be_blank
        expect(reviewable.payload["name"]).to be_blank
      end
    end
  end
end
