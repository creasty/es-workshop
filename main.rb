require 'dotenv'; Dotenv.load
require 'json'
require 'roka'

require_relative 'lib/base_search_service'


#=== User search service
#==============================================================================================
class UserSearchService < BaseSearchService

  NAME_SCORE = 10

  def apply_all
    q_normalized = normalized_query(params[:q])

    apply_name_filter(q_normalized)
  end

  def search(body)
    client.post('user/_search', body).body
  end

  def apply_name_filter(q)
    return if q.empty?

    root.highlight(
      's_name_*': {}
    )

    phrases(q).map do |phrase|
      {
        simple_query_string: simple_query_string(
          query:  quote_query(phrase),
          fields: ['s_name_en', 's_name_ja', 's_name_ja_phonetic']
        )
      }.tap do |query|
        root.disjunctive_queries << query
        root.func_scores << {
          filter:       query,
          boost_factor: NAME_SCORE,
        }
      end

      {
        multi_match: {
          type:   :phrase_prefix,
          query:  quote_query(phrase),
          fields: ['s_name_en', 's_name_ja', 's_name_ja_phonetic']
        }
      }.tap do |query|
        root.disjunctive_queries << query
        root.func_scores << {
          filter:       query,
          boost_factor: NAME_SCORE * 0.6,
        }
      end

      {
        or: [
          {
            simple_query_string: simple_query_string(
              query:  quote_query(phrase),
              fields: ['s_name_ja_phonetic']
            )
          },
          *Roka.convert(phrase).map { |romaji|
            {
              simple_query_string: simple_query_string(
                query:  quote_query(romaji),
                fields: ['s_name_ja_phonetic']
              )
            }
          }
        ]
      }.tap do |query|
        root.disjunctive_queries << query
        root.func_scores << {
          filter:       query,
          boost_factor: NAME_SCORE * 0.5
        }
      end

      {
        or: [
          {
            match_phrase_prefix: {
              s_name_ja_phonetic: quote_query(phrase),
            }
          },
          *Roka.convert(phrase).map { |romaji|
            {
              match_phrase_prefix: {
                s_name_ja_phonetic: quote_query(romaji),
              }
            }
          }
        ]
      }.tap do |query|
        root.disjunctive_queries << query
        root.func_scores << {
          filter:       query,
          boost_factor: NAME_SCORE * 0.4,
        }
      end
    end
  end

end


# user_ss = UserSearchService.new(
#   q: 'mukai',
#   fields: ['*'],
# )
# user_ss.perform!
# # puts JSON.dump(user_ss.raw_result)
# puts JSON.dump(user_ss.body)


class IssueSearchService < BaseSearchService

  TITLE_SCORE        = 150
  BODY_SCORE         = 30
  TIME_SCORE         = 10
  USER_SCORE         = 75
  COMMENT_BODY_SCORE = 15

  def after_initialize
    root.init_child(
      type:       :comment,
      score_mode: :max,
      inner_hits: {},
    )
    root.comment.optional!
  end

  def apply_all
    q_normalized = normalized_query(params[:q])

    apply_title_filter(q_normalized)
    apply_body_filter(q_normalized)
    apply_comment_body_filter(q_normalized)
    apply_user_rank(params[:user_ranks])
    apply_time_rank
  end

  def search(body)
    client.post('issue/_search', body).body
  end

  def apply_title_filter(q)
    return if q.empty?

    phrases(q).each do |phrase|
      {
        simple_query_string: simple_query_string(
          query:  phrase,
          fields: ['s_title']
        )
      }.tap do |query|
        root.disjunctive_queries << query
        root.func_scores << {
          filter:       query,
          boost_factor: TITLE_SCORE,
        }
      end
    end
  end

  def apply_body_filter(q)
    return if q.empty?

    phrases(q).each do |phrase|
      {
        simple_query_string: simple_query_string(
          query:  phrase,
          fields: ['s_body']
        )
      }.tap do |query|
        root.disjunctive_queries << query
        root.func_scores << {
          filter:       query,
          boost_factor: BODY_SCORE,
        }
      end
    end
  end

  def apply_time_rank
    root.func_scores << {
      script_score: {
        lang: :groovy,
        params: {
          weight:       TIME_SCORE,
          current_time: Time.now.to_i,
          a_month:      30 * 24 * 60 * 60,
          point:        10.0,
          e:            1.6,
        },
        script: <<-SCRIPT
          weight * (point / pow((current_time - _source.i_created_at) / a_month + 2, e))
        SCRIPT
      },
    }
  end

  def apply_comment_body_filter(q)
    return if q.empty?

    root.comment.highlight(
      s_body: {}
    )

    phrases(q).map do |phrase|
      {
        simple_query_string: simple_query_string(
          query:  quote_query(phrase),
          fields: ['s_body'],
        ),
      }.tap do |query|
        root.comment.disjunctive_queries << query
        root.comment.func_scores << {
          filter:       query,
          boost_factor: COMMENT_BODY_SCORE,
        }
      end
    end
  end

  def apply_user_rank(user_ranks)
    return unless user_ranks.is_a?(Hash)

    ranks    = user_ranks.map { |k, v| [k.to_s, v.to_f] }.to_h
    user_ids = user_ranks.map { |k, _| k.to_i }

    return if user_ids.empty?

    {
      terms: {
        i_user_id: user_ids
      }
    }.tap do |query|
      root.disjunctive_queries << query

      root.func_scores << {
        script_score: {
          lang: :groovy,
          params: {
            ranks:  ranks,
            weight: USER_SCORE,
          },
          script: <<-SCRIPT
            def id = _source.i_user_id as String
            weight * (ranks.containsKey(id) ? ranks[id] : 0)
          SCRIPT
        },
        filter: query,
      }
    end
  end

end


q = 'haru typo'

user_ss = UserSearchService.new(
  q: q,
  fields: ['*'],
)
user_ss.perform!

issue_ss = IssueSearchService.new(
  q: q,
  user_ranks: user_ss.ranks,
  fields: ['*'],
)
issue_ss.perform!
puts JSON.dump(issue_ss.raw_result)
