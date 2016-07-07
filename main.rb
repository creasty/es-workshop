require 'dotenv'; Dotenv.load
require 'json'
require 'roka'

require_relative 'lib/base_search_service'


#=== User search service
#==============================================================================================
class UserSearchService < BaseSearchService

  def apply_all
    apply_name_filter(params[:q])
  end

  def search(body)
    client.post('user/_search', body).body
  end

  def apply_name_filter(q)
    return if q.empty?

    root.disjunctive_queries << {
      simple_query_string: {
        query: q,
        fields: ['s_name_ja']
      }
    }
  end

end


user_ss = UserSearchService.new(
  q: '',
  fields: ['*'],
)
user_ss.perform!
puts JSON.dump(user_ss.raw_result)
# puts JSON.dump(user_ss.body)
