require 'dotenv'
require 'faraday'
require 'faraday_middleware'
require 'gimei'
require 'romaji'

require_relative 'models'

Dotenv.load


#=== API service
#==============================================================================================
class GithubApiService

  API_URL             = 'https://api.github.com'
  GITHUB_ACCESS_TOKEN = ENV['GITHUB_ACCESS_TOKEN']

  %i[get post put patch delete].each do |method|
    define_method method do |uri, data = nil|
      request(method, uri, data)
    end
  end


protected

  def client
    @client ||= Faraday.new(url: API_URL) do |c|
      c.headers['Accept']        = 'application/vnd.github.v3+json'
      c.headers['Authorization'] = 'token %s' % [GITHUB_ACCESS_TOKEN]

      c.request :json
      c.response :logger
      c.response :json
      c.adapter Faraday.default_adapter
      c.options.timeout = 30
    end
  end

  def request(method, uri, data = nil)
    client.send(method, uri, data)
  end

end



#=== Main
#==============================================================================================
class Scraper

  REPO      = 'vim-jp/issues'
  PAGE_SIZE = 100

  def perform!
    get_issues
    dump
  end

  def get_issues
    api.get('/repos/%s/issues' % [REPO], per_page: PAGE_SIZE).body.each do |issue_json|
      issue = create_issue(issue_json['number'], issue_json)

      api.get('/repos/%s/issues/%d/comments' % [REPO, issue.id], per_page: PAGE_SIZE).body.each do |comment_json|
        create_comment(issue.id, comment_json['id'], comment_json)
      end
    end
  end

  def create_issue(id, json)
    index[:issues][id] ||= Issue.new(
      id:         id,
      user_id:    json.dig('user', 'id'),
      title:      json['title'],
      body:       json['body'],
      created_at: Time.parse(json['created_at']).to_i,
    ).tap do |issue|
      create_user(issue.user_id, json.dig('user', 'login'))
    end
  end

  def create_user(id, username)
    return index[:users][id] if index[:users][id]

    name = Gimei.name

    index[:users][id] = User.new(
      id:       id,
      name_ja:  name.kanji,
      name_en:  Romaji.kana2romaji(name.katakana),
      username: username,
    )
  end

  def create_comment(issue_id, id, json)
    index[:comments][id] ||= Comment.new(
      id:         id,
      issue_id:   issue_id,
      user_id:    json.dig('user', 'id'),
      body:       json['body'],
      created_at: Time.parse(json['created_at']).to_i,
    ).tap do |comment|
      create_user(comment.user_id, json.dig('user', 'login'))
    end
  end

  def dump
    {
      issues:   Issue,
      users:    User,
      comments: Comment,
    }.each do |name, klass|
      json = index[name]
        .values
        .map { |m| m.as_json['attributes'] }

      klass.dump(json)
    end
  end

  def api
    @api ||= GithubApiService.new
  end

  def index
    @index ||= Hash.new { |h, k| h[k] = {} }
  end

end

Scraper.new.perform!
