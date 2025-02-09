# frozen_string_literal: true

require "rails_helper"

describe UserActionsController do
  describe "GET index" do
    subject(:user_actions) { get "/user_actions.json", params: params }

    context "when 'username' is not specified" do
      let(:params) { {} }

      it "fails" do
        user_actions
        expect(response).to have_http_status :bad_request
      end
    end

    context "when 'username' is specified" do
      let(:username) { post.user.username }
      let(:params) { { username: username } }
      let(:actions) { response.parsed_body["user_actions"] }
      let(:post) { create_post }

      before do
        UserActionManager.enable
      end

      it "renders list correctly" do
        user_actions
        expect(response).to have_http_status :ok
        expect(actions.first).to include "acting_name" => post.user.name,
                                         "post_number" => 1
        expect(actions.first).not_to include "email"
      end

      context "when 'acting_username' is provided" do
        let(:user) { Fabricate(:user) }

        before do
          PostActionNotifier.enable
          PostActionCreator.like(user, post)
          params[:acting_username] = user.username
        end

        it "filters its results" do
          user_actions
          expect(response).to have_http_status :ok
          expect(actions.first).to include "acting_username" => user.username
        end
      end

      context "when user's profile is hidden" do
        fab!(:post) { Fabricate(:post) }

        before do
          post.user.user_option.update_column(:hide_profile_and_presence, true)
        end

        context "when `allow_users_to_hide_profile` is disabled" do
          before do
            SiteSetting.allow_users_to_hide_profile = false
          end

          it "succeeds" do
            user_actions
            expect(response).to have_http_status :ok
          end
        end

        context "when `allow_users_to_hide_profile` is enabled" do
          it "returns a 404" do
            user_actions
            expect(response).to have_http_status :not_found
          end
        end
      end

      context "when checking other users' activity" do
        fab!(:another_user) { Fabricate(:user) }

        context "when user is anonymous" do
          UserAction.private_types.each do |action_type|
            action_name = UserAction.types.key(action_type)
            it "cannot list other users' actions of type: #{action_name}" do
              list_and_check(action_type, 404)
            end
          end
        end

        context "when user is logged in" do
          fab!(:user) { Fabricate(:user) }

          before do
            sign_in(user)
          end

          UserAction.private_types.each do |action_type|
            action_name = UserAction.types.key(action_type)
            it "cannot list other users' actions of type: #{action_name}" do
              list_and_check(action_type, 404)
            end
          end
        end

        context "when user is a moderator" do
          fab!(:moderator) { Fabricate(:moderator) }

          before do
            sign_in(moderator)
          end

          UserAction.private_types.each do |action_type|
            action_name = UserAction.types.key(action_type)
            it "cannot list other users' actions of type: #{action_name}" do
              list_and_check(action_type, 404)
            end
          end
        end

        context "when user is an admin" do
          fab!(:admin) { Fabricate(:admin) }

          before do
            sign_in(admin)
          end

          UserAction.private_types.each do |action_type|
            action_name = UserAction.types.key(action_type)
            it "can list other users' actions of type: #{action_name}" do
              list_and_check(action_type, 200)
            end
          end
        end

        def list_and_check(action_type, expected_response)
          get "/user_actions.json", params: {
            filter: action_type,
            username: another_user.username
          }

          expect(response.status).to eq(expected_response)
        end
      end

      context "when bad data is provided" do
        fab!(:user) { Fabricate(:user) }

        let(:params) do
          {
            filter: filter,
            username: username,
            offset: offset,
            limit: limit
          }
        end
        let(:filter) { "1,2" }
        let(:username) { user.username }
        let(:offset) { "0" }
        let(:limit) { "10" }

        %i[filter username offset limit].each do |parameter|
          context "when providing bad data for '#{parameter}'" do
            let(parameter) { { bad: "data" } }

            it "doesn't raise an error" do
              user_actions
              expect(response).not_to have_http_status :error
            end
          end
        end
      end
    end
  end
end
