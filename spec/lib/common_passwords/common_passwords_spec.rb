# frozen_string_literal: true

require "rails_helper"

describe CommonPasswords do
  it "the passwords file should exist" do
    expect(File.exist?(described_class::PASSWORD_FILE)).to eq(true)
  end

  describe "#common_password?" do
    before { described_class.stubs(:redis).returns(stub_everything) }

    subject { described_class.common_password? @password }

    it "returns false if password isn't in the common passwords list" do
      described_class.stubs(:password_list).returns(stub_everything(include?: false))
      @password = 'uncommonPassword'
      expect(subject).to eq(false)
    end

    it "returns false if password is nil" do
      described_class.expects(:password_list).never
      @password = nil
      expect(subject).to eq(false)
    end

    it "returns false if password is blank" do
      described_class.expects(:password_list).never
      @password = ""
      expect(subject).to eq(false)
    end

    it "returns true if password is in the common passwords list" do
      described_class.stubs(:password_list).returns(stub_everything(include?: true))
      @password = "password"
      expect(subject).to eq(true)
    end
  end

  describe '#password_list' do
    before { Discourse.redis.flushdb }
    after { Discourse.redis.flushdb }

    it "loads the passwords file if redis doesn't have it" do
      Discourse.redis.without_namespace.stubs(:scard).returns(0)
      described_class.expects(:load_passwords).returns(['password'])
      list = described_class.password_list
      expect(list).to respond_to(:include?)
    end

    it "doesn't load the passwords file if redis has it" do
      Discourse.redis.without_namespace.stubs(:scard).returns(10000)
      described_class.expects(:load_passwords).never
      list = described_class.password_list
      expect(list).to respond_to(:include?)
    end

    it "loads the passwords file if redis has an empty list" do
      Discourse.redis.without_namespace.stubs(:scard).returns(0)
      described_class.expects(:load_passwords).returns(['password'])
      list = described_class.password_list
      expect(list).to respond_to(:include?)
    end
  end

  context "missing password file" do
    it "tolerates it" do
      File.stubs(:readlines).with(described_class::PASSWORD_FILE).raises(Errno::ENOENT)
      expect(described_class.common_password?("password")).to eq(false)
    end
  end
end
