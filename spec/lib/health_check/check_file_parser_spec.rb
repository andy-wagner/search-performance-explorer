require "healthcheck_helper"

RSpec.describe HealthCheck::CheckFileParser do
  def checks(data)
    described_class.new(StringIO.new(data)).checks
  end

  it "read the supplied file and return a list of checks" do
    data = <<~DATA
      Tags,When I search for...,Then I...,see...,in the top ... results,Current position,Link,Last reviewed (Ctrl ;),Word count,Source,Duplicates?
      test,a,should,https://www.gov.uk/a,1
      test,b,should,https://www.gov.uk/b,1
    DATA

    expected = [
      HealthCheck::SearchCheck.new("a", "should", "/a", 1, 1, %w(test)),
      HealthCheck::SearchCheck.new("b", "should", "/b", 1, 1, %w(test)),
    ]
    expect(checks(data)).to eq(expected)
  end

  it "skip rows that don't have an integer for the top N number" do
    data = <<~DATA
      Tags,When I search for...,Then I...,see...,in the top ... results,Current position,Link,Last reviewed (Ctrl ;),Word count,Source,Duplicates?
      test,b,should,https://www.gov.uk/b,mistake
    DATA

    expected = []
    expect(checks(data)).to eq(expected)
  end

  it "skip rows that don't have a URL" do
    data = <<~DATA
      Tags,When I search for...,Then I...,see...,in the top ... results,Current position,Link,Last reviewed (Ctrl ;),Word count,Source,Duplicates?
      test,a,should,mistake,1
    DATA

    expected = []
    expect(checks(data)).to eq(expected)
  end

  it "skip rows that don't have a imperative" do
    data = <<~DATA
      Tags,When I search for...,Then I...,see...,in the top ... results,Current position,Link,Last reviewed (Ctrl ;),Word count,Source,Duplicates?
      test,a,,https://www.gov.uk/a,1
    DATA

    expected = []
    expect(checks(data)).to eq(expected)
  end

  it "skip rows that don't have a search term" do
    data = <<~DATA
      Tags,When I search for...,Then I...,see...,in the top ... results,Current position,Link,Last reviewed (Ctrl ;),Word count,Source,Duplicates?
      test,,should,https://www.gov.uk/a,1
    DATA

    expected = []
    expect(checks(data)).to eq(expected)
  end
end
