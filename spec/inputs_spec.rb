RSpec.describe Veri::Inputs do
  shared_examples_for "successful input processing" do |type, input, output = input|
    it "processes #{input} as #{type}" do
      expect(described_class.process(input, as: type)).to eq(output)
    end

    it "processes #{input} as optional #{type}" do
      expect(described_class.process(nil, as: type, optional: true)).to be_nil
    end
  end

  shared_examples_for "failed input processing" do |type, input|
    it "raises an error for invalid input #{input} processed as #{type}" do
      expect { described_class.process(input, as: type) }.to raise_error(Veri::InvalidArgumentError)
    end
  end

  describe "hashing_algorithm" do
    [:argon2, :bcrypt, :scrypt].each do |algorithm|
      it_behaves_like "successful input processing", :hashing_algorithm, algorithm
    end

    ["argon2", "foo", "", Veri, 123, [], {}, :foo].each do |invalid_input|
      it_behaves_like "failed input processing", :hashing_algorithm, invalid_input
    end
  end

  describe "duration" do
    [2.days, 30.minutes, 1.second, 100.years].each do |duration|
      it_behaves_like "successful input processing", :duration, duration
    end

    ["2 days", Veri, 123, [], {}, :foo].each do |invalid_input|
      it_behaves_like "failed input processing", :duration, invalid_input
    end
  end

  describe "non empty string" do
    ["valid string", " "].each do |string|
      it_behaves_like "successful input processing", :non_empty_string, string
    end

    [nil, [], {}, :foo, 123, Veri, ""].each do |invalid_input|
      it_behaves_like "failed input processing", :non_empty_string, invalid_input
    end
  end

  describe "model" do
    { "User" => User, Client => Client }.each do |model_name, model|
      it_behaves_like "successful input processing", :model, model_name, model
    end

    ["NonExistentModel", "Veri", Veri, 123, [], {}, :foo].each do |invalid_input|
      it_behaves_like "failed input processing", :model, invalid_input
    end
  end

  describe "authenticatable" do
    it_behaves_like "successful input processing", :authenticatable, User.new

    [Client.new, User, "User", :user, 123, [], {}].each do |invalid_input|
      it_behaves_like "failed input processing", :authenticatable, invalid_input
    end
  end

  describe "request" do
    it_behaves_like "successful input processing", :request, ActionDispatch::Request.new({})

    [ApplicationController.new, User, "Request", :request, 123, [], {}].each do |invalid_input|
      it_behaves_like "failed input processing", :request, invalid_input
    end
  end
end
