require "rails_helper"

RSpec.describe ActionText::Embed, type: :model do
  it "renders name with ActionText to_plain_text" do
    embed = action_text_embeds(:one)
    expect(embed.attachable_plain_text_representation).to eq("[#{embed.url}]")
  end
end
