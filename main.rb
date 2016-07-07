require 'dotenv'; Dotenv.load
require 'json'
require 'roka'

require_relative 'lib/base_search_service'


#=== User search service
#==============================================================================================
class UserSearchService < BaseSearchService

  def apply_all
    apply_id_filter
  end

  def search(body)
    client.post('user/_search', body).body
  end

  def apply_id_filter
    root.filters << {
      term: {
        i_user_id: 518808
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
