require_relative "../../../spec/es_spec_helper"

describe "connect using HTTP Authentication", :elasticsearch_secure => true do
  subject do
    require "logstash/outputs/elasticsearch"
    settings = {
      "user" => "logstash_user",
      "password" => "changeme",
    }
    next LogStash::Outputs::ElasticSearch.new(settings)
  end

  before :each do
    @es = get_client({user: "elastic", password: "changeme"})
    subject.register
  end

  after :each do
    @es.indices.delete(index: 'logstash-*')
  end

  it "sends events to ES" do
    expect {
      subject.multi_receive([LogStash::Event.new("message" => "sample message here")])
    }.to_not raise_error
    @es.indices.refresh
    results = @es.search(index: 'logstash-*', q: '*')
    insist { results["hits"]["total"] } == 1
    insist { results["hits"]["hits"][0]["_source"]["message"] } == "sample message here"
  end
  
  it "can upload the logstash template" do
    subject.multi_receive([
      LogStash::Event.new("message" => "sample message here"),
      LogStash::Event.new("somevalue" => 100),
      LogStash::Event.new("somevalue" => 10),
      LogStash::Event.new("somevalue" => 1),
      LogStash::Event.new("country" => "us"),
      LogStash::Event.new("country" => "at"),
      LogStash::Event.new("geoip" => { "location" => [ 0.0, 0.0 ] })
    ])

    @es.indices.refresh
    results = @es.search(:q => "country.keyword:\"us\"")
    insist { results["hits"]["total"] } == 1
    insist { results["hits"]["hits"][0]["_source"]["country"] } == "us"

    # partial or terms should not work.
    results = @es.search(:q => "country.keyword:\"u\"")
    insist { results["hits"]["total"] } == 0
  end
  
  
end

describe "role based access control", :elasticsearch_secure => true do
  subject do
    require "logstash/outputs/elasticsearch"
    settings = {
      "user" => "logstash_user",
      "password" => "changeme",
      "index" => "beats"
    }
    next LogStash::Outputs::ElasticSearch.new(settings)
  end

  before :each do
    @es = get_client({user: "elastic", password: "changeme"})
    @es.indices.create(index: 'beats')
    subject.register
  end

  after :each do
    @es.indices.delete(index: 'beats')
  end

  it "cannot send events to beats index" do
    subject.multi_receive([LogStash::Event.new("message" => "sample message here")])
    @es.indices.refresh
    results = @es.search(index: 'beats', q: '*')
    insist { results["hits"]["total"] } == 0
  end
end
