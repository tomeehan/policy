require "rails_helper"

RSpec.describe "Heroku app.json" do
  it "has valid JSON syntax" do
    expect {
      JSON.parse(File.read("app.json"))
    }.not_to raise_error
  end
end
