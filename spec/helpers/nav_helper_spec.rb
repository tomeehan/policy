require "rails_helper"

RSpec.describe NavHelper, type: :helper do
  describe "#nav_link_to" do
    it "accepts block" do
      block_link = helper.nav_link_to("/block") { "Block Link" }
      expect(block_link).to eq(%(<a href="/block">Block Link</a>))
    end

    it "accepts block with classes" do
      block_link = helper.nav_link_to("/block-class", class: "nav") { "Block Link with Classes" }
      expect(block_link).to eq(%(<a class="nav" href="/block-class">Block Link with Classes</a>))
    end

    it "link with url" do
      link = helper.nav_link_to("GoRails", "https://gorails.com")
      expect(link).to eq(%(<a href="https://gorails.com">GoRails</a>))
    end

    it "link with classes" do
      link = helper.nav_link_to("Link with Classes", "/link-class", class: "nav")
      expect(link).to eq(%(<a class="nav" href="/link-class">Link with Classes</a>))
    end

    it "link with data attributes" do
      link = helper.nav_link_to("Link with data attrs", "/link-attrs", class: "nav", data: {test: "foo"})
      expect(link).to eq(%(<a class="nav" data-test="foo" href="/link-attrs">Link with data attrs</a>))
    end

    it "link active class" do
      allow(helper.request).to receive(:path).and_return("/link-active")
      link = helper.nav_link_to("Link active", "/link-active")
      expect(link).to eq(%(<a class="active" href="/link-active">Link active</a>))
    end

    it "link custom active class" do
      allow(helper.request).to receive(:path).and_return("/custom-active-class")
      link = helper.nav_link_to("Custom active class", "/custom-active-class", active_class: "custom_active")
      expect(link).to eq(%(<a class="custom_active" href="/custom-active-class">Custom active class</a>))
    end

    it "link custom inactive class" do
      link = helper.nav_link_to("Custom inactive class", "/custom-inactive", inactive_class: "custom_inactive")
      expect(link).to eq(%(<a class="custom_inactive" href="/custom-inactive">Custom inactive class</a>))
    end

    it "link starts with active class" do
      allow(helper.request).to receive(:path).and_return("/foo/1/bar/1")
      link = helper.nav_link_to("Starts with", "/starts", starts_with: "/foo")
      expect(link).to eq(%(<a class="active" href="/starts">Starts with</a>))
    end
  end
end
