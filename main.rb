require 'dotenv'; Dotenv.load
require 'json'
require 'roka'

require_relative 'lib/base_search_service'


#=== User search service
#==============================================================================================
class UserSearchService < BaseSearchService

  def apply_all
    q_normalized = normalized_query(params[:q])

    apply_name_filter(q_normalized)
  end

  def search(body)
    client.post('user/_search', body).body
  end

  def apply_name_filter(q)
    return if q.empty?

    root.disjunctive_queries << {
      simple_query_string: {
        query: q,
        fields: ['s_name_ja', 's_name_ja_phonetic', 's_name_en']
      }
    }
    Roka.convert(q).each do |romaji|
      root.disjunctive_queries << {
        simple_query_string: {
          query: romaji,
          fields: ['s_name_en']
        }
      }
    end
  end

end


user_ss = UserSearchService.new(
  q: 'mukai',
  fields: ['*'],
)
user_ss.perform!
puts JSON.dump(user_ss.raw_result)
# puts JSON.dump(user_ss.body)
