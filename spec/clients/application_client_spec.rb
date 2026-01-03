require "rails_helper"

RSpec.describe ApplicationClient do
  let(:client) { ApplicationClient.new(token: "test") }

  describe "authorization" do
    it "sends authorization header" do
      stub_request(:get, "https://example.org/").with(headers: {"Authorization" => "Bearer test"})
      expect { client.send(:get, "/") }.not_to raise_error
    end

    it "sends basic auth" do
      stub_request(:get, "https://example.org/")
      basic_client = ApplicationClient.new(basic_auth: {username: "user", password: "pass"})
      basic_client.send(:get, "/")
      expect(WebMock).to have_requested(:get, "https://example.org/").with(headers: {"Authorization" => "Basic #{Base64.strict_encode64("user:pass")}"})
    end
  end

  describe "GET requests" do
    it "get" do
      stub_request(:get, "https://example.org/test")
      expect { client.send(:get, "/test") }.not_to raise_error
    end

    it "get with query params" do
      stub_request(:get, "https://example.org/test").with(query: {"foo" => "bar"})
      expect { client.send(:get, "/test", query: {foo: "bar"}) }.not_to raise_error
    end

    it "get with query params as a string" do
      stub_request(:get, "https://example.org/test").with(query: {"foo" => "bar"})
      expect { client.send(:get, "/test", query: "foo=bar") }.not_to raise_error
    end

    it "override BASE_URI by passing in full url" do
      stub_request(:get, "https://other.org/test")
      expect { client.send(:get, "https://other.org/test") }.not_to raise_error
    end
  end

  describe "POST requests" do
    it "post" do
      stub_request(:post, "https://example.org/test").with(body: {"foo" => {"bar" => "baz"}}.to_json)
      expect { client.send(:post, "/test", body: {foo: {bar: "baz"}}) }.not_to raise_error
    end

    it "post with string body" do
      stub_request(:post, "https://example.org/test").with(body: "foo")
      expect { client.send(:post, "/test", body: "foo") }.not_to raise_error
    end

    it "post with custom content-type" do
      headers = {"Content-Type" => "application/x-www-form-urlencoded"}
      stub_request(:post, "https://example.org/test").with(body: {"foo" => "bar"}.to_json, headers: headers)
      expect { client.send(:post, "/test", body: {foo: "bar"}, headers: headers) }.not_to raise_error
    end

    it "multipart form data with file_fixture" do
      file = file_fixture("avatar.jpg")
      form_data = {"field1" => "value1", "file" => File.open(file)}
      stub_request(:post, "https://example.org/upload").to_return(status: 200)
      expect { client.send(:post, "/upload", form_data: form_data) }.not_to raise_error
    end
  end

  describe "PATCH requests" do
    it "patch" do
      stub_request(:patch, "https://example.org/test").with(body: {"foo" => "bar"}.to_json)
      expect { client.send(:patch, "/test", body: {foo: "bar"}) }.not_to raise_error
    end

    it "multipart form data with file_fixture and patch" do
      file = file_fixture("avatar.jpg")
      form_data = {"field1" => "value1", "file" => File.open(file)}
      stub_request(:patch, "https://example.org/update").to_return(status: 200)
      expect { client.send(:patch, "/update", form_data: form_data) }.not_to raise_error
    end
  end

  describe "PUT requests" do
    it "put" do
      stub_request(:put, "https://example.org/test").with(body: {"foo" => "bar"}.to_json)
      expect { client.send(:put, "/test", body: {foo: "bar"}) }.not_to raise_error
    end

    it "multipart form data with file_fixture and put" do
      file = file_fixture("avatar.jpg")
      form_data = {"field1" => "value1", "file" => File.open(file)}
      stub_request(:put, "https://example.org/update").to_return(status: 200)
      expect { client.send(:put, "/update", form_data: form_data) }.not_to raise_error
    end
  end

  describe "DELETE requests" do
    it "delete" do
      stub_request(:delete, "https://example.org/test")
      expect { client.send(:delete, "/test") }.not_to raise_error
    end
  end

  describe "response parsing" do
    it "parses json" do
      stub_request(:get, "https://example.org/test").to_return(body: {"foo" => {"bar" => "baz"}}.to_json, headers: {content_type: "application/json"})
      result = client.send(:get, "/test")
      expect(result.code).to eq("200")
      expect(result.content_type).to eq("application/json")
      expect(result.foo.bar).to eq("baz")
    end

    it "parses xml" do
      stub_request(:get, "https://example.org/test").to_return(body: {"foo" => "bar"}.to_xml, headers: {content_type: "application/xml"})
      result = client.send(:get, "/test")
      expect(result.code).to eq("200")
      expect(result.content_type).to eq("application/xml")
      expect(result.xpath("//foo").children.first.to_s).to eq("bar")
    end
  end

  describe "error handling" do
    it "raises Unauthorized on 401" do
      stub_request(:get, "https://example.org/test").to_return(status: 401)
      expect { client.send(:get, "/test") }.to raise_error(ApplicationClient::Unauthorized)
    end

    it "raises Forbidden on 403" do
      stub_request(:get, "https://example.org/test").to_return(status: 403)
      expect { client.send(:get, "/test") }.to raise_error(ApplicationClient::Forbidden)
    end

    it "raises NotFound on 404" do
      stub_request(:get, "https://example.org/test").to_return(status: 404)
      expect { client.send(:get, "/test") }.to raise_error(ApplicationClient::NotFound)
    end

    it "raises RateLimit on 429" do
      stub_request(:get, "https://example.org/test").to_return(status: 429)
      expect { client.send(:get, "/test") }.to raise_error(ApplicationClient::RateLimit)
    end

    it "raises InternalError on 500" do
      stub_request(:get, "https://example.org/test").to_return(status: 500)
      expect { client.send(:get, "/test") }.to raise_error(ApplicationClient::InternalError)
    end

    it "raises Error on other status codes" do
      stub_request(:get, "https://example.org/test").to_return(status: 418)
      expect { client.send(:get, "/test") }.to raise_error(ApplicationClient::Error)
    end
  end

  describe "link header parsing" do
    it "parses link header" do
      stub_request(:get, "https://example.org/pages").to_return(headers: {"Link" => "<https://example.org/pages?page=2>; rel=\"next\", <https://example.org/pages?page=1>; rel=\"prev\""})
      response = client.send(:get, "/pages")
      expect(response.link_header[:next]).to eq("https://example.org/pages?page=2")
      expect(response.link_header[:prev]).to eq("https://example.org/pages?page=1")
    end

    it "handles missing link header" do
      stub_request(:get, "https://example.org/pages")
      response = client.send(:get, "/pages")
      expect(response.link_header).to be_empty
    end
  end
end

RSpec.describe "ApplicationClient with basic auth" do
  let(:basic_auth_client) do
    Class.new(ApplicationClient) do
      self::BASE_URI = "https://example.org"

      def basic_auth
        {username: "user", password: "pass"}
      end
    end
  end

  it "sends basic auth" do
    stub_request(:get, "https://example.org/")
    basic_auth_client.new.send :get, "/"
    expect(WebMock).to have_requested(:get, "https://example.org/").with(headers: {"Authorization" => "Basic #{Base64.strict_encode64("user:pass")}"})
  end
end

RSpec.describe "Custom ApplicationClient" do
  let(:test_api_client) do
    Class.new(ApplicationClient) do
      self::BASE_URI = "https://test.example.org"

      def root
        get "/"
      end

      def content_type
        "application/xml"
      end

      def all_pages
        with_pagination("/pages", query: {per_page: 100}) do |response|
          response.link_header[:next]
        end
      end

      def all_projects
        with_pagination("/projects", query: {per_page: 100}) do |response|
          next_page = response.parsed_body.pagination.next_page
          {page: next_page} if next_page
        end
      end
    end
  end

  it "with_pagination and url" do
    stub_request(:get, "https://test.example.org/pages?per_page=100").to_return(headers: {"Link" => "<https://test.example.org/pages?page=2>; rel=\"next\""})
    stub_request(:get, "https://test.example.org/pages?per_page=100&page=2")
    expect { test_api_client.new(token: "test").all_pages }.not_to raise_error
  end

  it "with_pagination with query hash" do
    stub_request(:get, "https://test.example.org/projects?per_page=100").to_return(body: {pagination: {next_page: 2}}.to_json, headers: {content_type: "application/json"})
    stub_request(:get, "https://test.example.org/projects?per_page=100&page=2").to_return(body: {pagination: {prev_page: 1}}.to_json, headers: {content_type: "application/json"})
    expect { test_api_client.new(token: "test").all_projects }.not_to raise_error
  end

  it "get" do
    stub_request(:get, "https://test.example.org/")
    expect { test_api_client.new(token: "test").root }.not_to raise_error
  end

  it "content type" do
    stub_request(:get, "https://test.example.org/").with(headers: {"Accept" => "application/xml"})
    expect { test_api_client.new(token: "test").root }.not_to raise_error
  end

  it "other error" do
    stub_request(:get, "https://test.example.org/").to_return(status: 418)
    expect { test_api_client.new(token: "test").root }.to raise_error(test_api_client::Error)
  end
end

RSpec.describe "ApplicationClient with custom response parser" do
  let(:custom_response_client) do
    Class.new(ApplicationClient) do
      self::BASE_URI = "https://example.org"
      self::Response::PARSER["application/json"] = ->(response) { JSON.parse(response.body) }
    end
  end

  it "uses custom json object class" do
    stub_request(:get, "https://example.org/").to_return(body: {foo: :bar}.to_json, headers: {content_type: "application/json"})
    response = custom_response_client.new.send :get, "/"
    expect(WebMock).to have_requested(:get, "https://example.org/")
    expect(response.parsed_body).to be_a(Hash)
  end
end

RSpec.describe "ApplicationClient fallback parser" do
  let(:fallback_client) do
    Class.new(ApplicationClient) do
      self::BASE_URI = "https://example.org"
    end
  end

  it "handles no content type" do
    stub_request(:get, "https://example.org/").to_return(body: {foo: :bar}.to_json)
    response = fallback_client.new.send :get, "/"
    expect(response.content_type).to be_nil
  end
end
