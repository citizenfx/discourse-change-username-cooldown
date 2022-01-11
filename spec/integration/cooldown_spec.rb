# frozen_string_literal: true

require 'rails_helper'

describe 'Cooldown' do
    let(:original_change_period) { SiteSetting.username_change_period }
    let(:time) { DateTime.now }

    before do
        SiteSetting.username_change_period = 0
    end

    after do
        SiteSetting.username_change_period = original_change_period
    end

    describe 'when logged in' do
        let(:user) { Fabricate(:user, created_at: time - 1.year) }
        let(:user2) { Fabricate(:user, created_at: time - 1.year) }

        before do
            sign_in(user)
        end

        it 'cant change someone elses username' do
            get "/u/#{user2.username}.json"

            body = JSON.parse(response.body)

            expect(body['user']['can_edit_username']).to be(false)
        end

        describe 'when change username is available' do
            before do
                user.user_custom_fields.create(name: 'username_changed_at', value: time)
            end

            it 'should return proper payload' do
                freeze_time(time) do
                    get "/u/#{user.username}.json"

                    body = JSON.parse(response.body)

                    expect(body['user']['can_edit_username']).to be(true)
                end
            end
        end

        describe 'when change username is on cooldown' do
            before do
                user.user_custom_fields.create(name: 'username_changed_at', value: time)
            end

            it 'should return the proper payload' do
                freeze_time(time) do
                    get "/u/#{user.username}.json"

                    body = JSON.parse(response.body) 

                    expected_date = (time + SiteSetting.change_username_cooldown.days).change(usec: 0)

                    expect(body['user']['can_edit_username']).to be(false)
                    expect(body['user']['username_changed_at']).to eq(time.to_s)
                    expect(DateTime.parse(body['user']['username_change_available_on'])).to eq(expected_date)
                end
            end
        end
    end
end