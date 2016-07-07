require 'benchmark'

require_relative 'client'
require_relative 'query_builder'
require_relative 'result_parser'
require_relative 'text_helpers'

class BaseSearchService

  include TextHelpers

  DEFAULT_PAGE_SIZE = 30

  attr_reader :params
  attr_reader :body

  def initialize(params = {})
    @params = params.freeze

    after_initialize
  end

  def after_initialize
    # nothing here
  end

  def apply_all
    raise 'Unimplemented'
  end

  def search(body)
    raise 'Unimplemented'
  end

  def client
    @client ||= Client.new
  end

  def perform!
    if @raw_result
      raise 'Already performed!'
    end

    apply_all
    raw_result
  end

  def per_page
    @per_page ||= params[:per_page] ? params[:per_page].to_i : DEFAULT_PAGE_SIZE
  end

  def page
    return @page if @page
    @page = params[:page] ? params[:page].to_i : 1
    @page = 1 if @page <= 0
    @page
  end

  def fields
    return @fields if defined?(@fields)
    @fields = unless params[:fields].nil?
      Array(params[:fields]).flat_map { |f| f.to_s.split(',') }
    end
  end

  def raw_result
    return @raw_result if @raw_result

    body = {
      sort: { _score: :desc }
    }

    body[:size]   = per_page if per_page
    body[:from]   = (page - 1) * per_page if page
    body[:fields] = fields unless fields.nil?

    @body       = root.build(body)
    @raw_result = search(@body)
  end

  def result
    @result ||= ResultParser.new.parse(raw_result)
  end

  def hits_count
    raw_result['hits']['total']
  end

  def ranks
    @ranks ||= raw_result.dig(*%w(hits hits)).map do |r|
      [r['_id'].to_i, r['_score']]
    end.to_h
  end

protected

  def root
    @root ||= QueryBuilder.new
  end

end
