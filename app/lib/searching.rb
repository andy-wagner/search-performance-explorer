class Searching
  ENHANCED_FIELDS = %w(
    document_collections
    specialist_sectors
    policies
    taxons
    mainstream_browse_pages
  ).freeze
  HEAD_FIELDS = %w(
    popularity
    is_historic
  ).freeze
  SECONDARY_HEAD_FIELDS = %w(
    people
    organisations
  ).freeze
  FIELDS = %w(
    description
    format
    link
    public_timestamp
    title
    content_id
  ).freeze + ENHANCED_FIELDS + HEAD_FIELDS + SECONDARY_HEAD_FIELDS
  require 'gds_api/rummager'
  attr_reader :params
  def initialize(params)
    @params = params
  end

  def count
    return 10 if params["count"].blank?
    return 1000 if params["count"].to_i > 1000
    params["count"]
  end

  def call
    rummager = GdsApi::Rummager.new(Plek.new.find('rummager'))
    findings_new_left = rummager.search(
      q: params["search_term"],
      fields: FIELDS,
      count: count.to_s,
      ab_tests: "#{params['which_test']}:A",
      c: Time.now.getutc.to_s
      )
    findings_new_right = rummager.search(
      q: params["search_term"],
      fields: FIELDS,
      count: count.to_s,
      ab_tests: "#{params['which_test']}:B",
      c: Time.now.getutc.to_s
      )
    Results.new(findings_new_left, findings_new_right)
  end

  class Results
    attr_reader :left_total, :left_missing, :right_total, :right_missing, :left, :right, :result_count
    def initialize(left, right)
      @result_count = right['results'].count > left['results'].count ? right['results'].count : left['results'].count
      @left = (0..result_count - 1).map { |i| Result.new(left['results'][i]) }
      @right = (0..result_count - 1).map { |i| Result.new(right['results'][i]) }
      @left_total = left['total']
      @right_total = right['total']
      @left_missing = @left_total - left['results'].count
      @right_missing = @right_total - right['results'].count
    end

    def rows
      left.zip(right)
    end

    def search_left_list_for_link(link)
      left.index { |result| result["link"].include?(link) }
    end

    def score_difference(link, position)
      sd = search_left_list_for_link(link).present? ? (search_left_list_for_link(link) - position) : "++++"
      return ["+#{sd}", "up-box"] if sd == "++++" || sd.positive?
      return ["N/A", "changeless-box"] if sd.zero?
      [sd.to_s, "down-box"]
    end
  end

  class Result
    require 'uri'
    delegate :[], to: :@info
    def initialize(info)
      @info = info
    end

    def enhanced_results(enhanced_fields)
      return_hash = {}
      enhanced_fields.each do |field|
        next unless @info[field].present?
        return_hash[field.titleize] = @info[field].map { |t| link_title_pair(t, field) }
      end
      return_hash
    end

    def get_head_info_list(fields)
      head_info_list = [@info['format'].humanize, date_format(@info['public_timestamp'])]
      head_info_list << historical_or_current(@info['is_historic']) if fields.include?("is_historic")
      head_info_list << "Popularity: #{@info['popularity']}" if fields.include?("popularity")
      head_info_list
    end

    def link
      format_link(@info['link'])
    end

    def name
      make_readable(@info['link']).strip
    end

    def second_head(fields)
      (fields.include?("people") ? people : []) + (fields.include?("organisations") ? organisations : [])
    end

  private

    def date_format(date)
      DateTime.parse(date).strftime("%B %Y") unless date.nil?
    end

    def format_link(link, extra = "")
      return link if link == nil || link.start_with?("https://", "http://")
      return "https://#{link}" if link.start_with?("www.")
      "https://gov.uk" + extra + link
    end

    def historical_or_current(check)
      return if check.nil?
      check ? "Historical" : "Current"
    end

    def link_title_pair(link, field)
      return [make_readable(link), ''] if field == "taxons"
      return [make_readable(link), format_link(link, "/government/policies/")] if field == "policies"
      return [make_readable(link), format_link(link, "/browse/")] if field == "mainstream_browse_pages"
      [link['title'], format_link(link['link'])]
    end

    def make_readable(text)
      text.gsub("/", " / ").tr("-", " ")
    end

    def organisations
      return [] unless @info["organisations"].present?
      @info['organisations'].map do |details|
        [details['title'], format_link(details['link'])]
      end
    end

    def people
      return [] unless @info["people"].present?
      @info['people'].map do |details|
        [details['title'], format_link(details['link'])]
      end
    end
  end
end
