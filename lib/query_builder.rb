class QueryBuilder

  attr_reader :filters
  attr_reader :queries
  attr_reader :disjunctive_filters
  attr_reader :disjunctive_queries
  attr_reader :func_scores
  attr_reader :sub_bodies

  attr_accessor :func_score_mode
  attr_accessor :func_boost_mode

  def initialize(base = {})
    @base = base

    @filters             = []
    @queries             = []
    @disjunctive_filters = []
    @disjunctive_queries = []
    @func_scores         = []
    @highlights          = {}
    @sub_bodies          = {}

    @func_score_mode = :sum
    @func_boost_mode = :sum

    @optional = false
  end

  def highlight(hash = {})
    hash.each { |field, opt| @highlights[field] = opt }
    self
  end

  def build(_body = {})
    return @body if @body

    body     = {}
    _filters = []
    _queries = []

    if @filters.any?
      _filters += @filters
    end
    if @queries.any?
      _queries += @queries
    end
    if @disjunctive_filters.any?
      _filters << { or: @disjunctive_filters }
    end
    if @disjunctive_queries.any?
      _queries << { bool: { should: @disjunctive_queries, minimum_should_match: 1 } }
    end

    if @func_scores.any?
      _queries << {
        function_score: {
          score_mode: @func_score_mode,
          boost_mode: @func_boost_mode,
          functions:  @func_scores,
        }
      }
    end

    @sub_bodies.each do |type, builder|
      builder.build.tap do |sub_body|
        next unless sub_body[:query] || sub_body[:filter]

        sub_query = { type => sub_body }

        if builder.optional?
          sub_query = {
            bool: {
              should: [
                sub_query,
                { match_all: {} },
              ]
            }
          }
        end

        _queries << sub_query
      end
    end

    if _filters.any?
      body[:filter] = { and: _filters }
    end
    if _queries.any?
      body[:query] = { bool: { must: _queries } }
    end

    if @highlights.any?
      highlights = { fields: @highlights }

      if (name = @base[:type] || @base[:path])
        if @base[:inner_hits]
          @base[:inner_hits][:highlight] = highlights
        else
          raise "Highlight can't be provided for `%s` without inner_hits" % [name]
        end
      else
        body[:highlight] = highlights
      end
    end

    @body = body.merge(@base).merge(_body)
  end

  def optional!
    @optional = true
  end
  def optional?
    !!@optional
  end

  def init_child(opt)
    init_sub_body(:has_child, opt[:type], opt)
  end

  def init_parent(opt)
    init_sub_body(:has_parent, opt[:type], opt)
  end

private

  def init_sub_body(type, name, opt)
    if opt[:inner_hits]
      opt[:inner_hits][:name] ||= [type, SecureRandom.uuid].join('.')
    end

    self.class.new(opt).tap do |sub_builder|
      @sub_bodies[type] = sub_builder
      define_singleton_method(name) { sub_builder }
    end
  end

end
