require 'dotenv'; Dotenv.load
require 'json'
require 'roka'

require_relative 'lib/base_search_service'


#=== User search service
#==============================================================================================
class UserSearchService < BaseSearchService

  def apply_all
  end

  def search(body)
    client.post('user/_search', body).body
  end

end


user_ss = UserSearchService.new(
  q: '',
  fields: ['*'],
)
user_ss.perform!
puts JSON.dump(user_ss.raw_result)
