# frozen_string_literal: true

require 'rails_helper'

describe EmailValidator do
  def blocks?(email)
    user = Fabricate.build(:user, email: email)
    validator = EmailValidator.new(attributes: :email)
    validator.validate_each(user, :email, user.email)
    user.errors[:email].present?
  end

  context "blocked email" do
    it "doesn't add an error when email doesn't match a blocked email" do
      expect(blocks?('sam@sam.com')).to eq(false)
    end

    it "adds an error when email matches a blocked email" do
      ScreenedEmail.create!(email: 'sam@sam.com', action_type: ScreenedEmail.actions[:block])
      expect(blocks?('sam@sam.com')).to eq(true)
      expect(blocks?('SAM@sam.com')).to eq(true)
    end

    it "blocks based on blocked_email_domains" do
      SiteSetting.blocked_email_domains = "email.com|mail.com|e-mail.com"
      expect(blocks?('sam@email.com')).to eq(true)
      expect(blocks?('sam@EMAIL.com')).to eq(true)
      expect(blocks?('sam@bob.email.com')).to eq(true)
      expect(blocks?('sam@e-mail.com')).to eq(true)
      expect(blocks?('sam@googlemail.com')).to eq(false)
    end

    it "blocks based on allowed_email_domains" do
      SiteSetting.allowed_email_domains = "googlemail.com|email.com"
      expect(blocks?('sam@email.com')).to eq(false)
      expect(blocks?('sam@EMAIL.com')).to eq(false)
      expect(blocks?('sam@bob.email.com')).to eq(false)
      expect(blocks?('sam@e-mail.com')).to eq(true)
      expect(blocks?('sam@googlemail.com')).to eq(false)
      expect(blocks?('sam@email.computers.are.evil.com')).to eq(true)
    end
  end

  context "auto approve email domains" do
    it "works as expected" do
      SiteSetting.auto_approve_email_domains = "example.com"

      expect(EmailValidator.can_auto_approve_user?("foobar@example.com.fr")).to eq(false)
      expect(EmailValidator.can_auto_approve_user?("foobar@example.com")).to eq(true)
    end

    it "returns false if domain not present in allowed_email_domains" do
      SiteSetting.allowed_email_domains = "googlemail.com"
      SiteSetting.auto_approve_email_domains = "example.com|googlemail.com"

      expect(EmailValidator.can_auto_approve_user?("foobar@example.com")).to eq(false)
      expect(EmailValidator.can_auto_approve_user?("foobar@googlemail.com")).to eq(true)
    end
  end
end
