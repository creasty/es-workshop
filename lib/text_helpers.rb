require 'json'
require 'nkf'

module TextHelpers

  # When simple_query_string search, disable '+' operater indicating AND
  # https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-simple-query-string-query.html
  SIMPLE_QUERY_STRING_FLAGS = %w[
    OR
    NOT
    PREFIX
    PHRASE
    PRECEDENCE
    ESCAPE
    WHITESPACE
    FUZZY
    NEAR
    SLOP
  ].join('|').freeze

  # Escape reserved characters for query string
  # Please see https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-query-string-query.html
  QUERY_STRING_RESERVED_CHARS = %w[\\ + - = && || > < ! ( ) { } [ ] ^ " ~ * ? : /].freeze
  QUERY_STRING_RESERVED_PATTERN = Regexp.new(
    QUERY_STRING_RESERVED_CHARS
    .map { |c| Regexp.escape(c) }
    .join('|')
  ).freeze

  # Normalize whitespace and kana
  #
  # normalized_query(' [　] a1ａ１あｱ')
  # => '[ ]a1a1アア'
  def normalized_query(query, katakana: false)
    return '' unless query
    option = %w[-Z1 -w]
    option << '--katakana' if katakana
    NKF.nkf(option.join(' '), query).gsub(/[[:space:]]+/, ' ').strip.downcase
  end

  def escape_query(query)
    query.gsub(QUERY_STRING_RESERVED_PATTERN, '\\\\\0')
  end

  # Quote entire query
  #
  # quote_query('foo b"ar')
  # => '"foo b\"ar"'
  def quote_query(query)
    JSON.dump(query)
  end

  def keywords(query)
    query.to_s.strip.split(/[[:space:]]+/)
  end

  # Quote query word by word
  #
  # quote_keywords('foo b"ar')
  # => '"foo" "b\"ar"'
  def quote_keywords(query)
    keywords(query)
      .map { |k| quote_query(k) }
      .join(' ')
  end

  # Create combination of phrases
  #
  # phrases('ruby on rails 4')
  # => [
  #   'ruby on rails 4',
  #   'ruby on rails',
  #   'ruby on',
  #   'ruby',
  #   'on rails 4',
  #   'on rails',
  #   'on',
  #   'rails 4',
  #   'rails',
  #   '4',
  # ]
  def phrases(query)
    parts = keywords(query)
    parts_size = parts.size

    [*0..parts_size]
    .combination(2)
    .map { |(a, b)| parts[a...parts_size - (b - a - 1)].join(' ') }
  end

  def simple_query_string(hash = {})
    hash.dup.tap do |h|
      h[:default_operator] ||= :and
      h[:flags]            ||= SIMPLE_QUERY_STRING_FLAGS
    end
  end

  def nested(hash = {})
    hash.dup.tap do |h|
      if h[:inner_hits]
        h[:inner_hits][:name] ||= [:nested, SecureRandom.uuid].join('.')
      end
    end
  end

end
