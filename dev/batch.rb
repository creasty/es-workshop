require 'dotenv'
require 'gimei'
require 'json'
require 'pathname'
require 'random_bell'
require 'romaji'

require_relative 'models'

Dotenv.load

ROOT_PATH = Pathname.new(File.expand_path('../', __FILE__))

class BatchFileCreation

  INDEX_NAME = ENV['INDEX_NAME']

  def perform!
    create_users

    process_comments
    process_issues
    process_users
    print_json
  end

  def process_comments
    Comment.all.each do |comment|
      api_calls << {
        index: {
          _index:  INDEX_NAME,
          _type:   :comment,
          _id:     comment.id,
          _parent: comment.issue_id,
        }
      }
      api_calls << {
        i_comment_id: comment.id,
        i_issue_id:   comment.issue_id,
        i_user_id:    comment.user_id,
        s_body:       comment.body,
        i_created_at: comment.created_at,
      }
    end
  end

  def process_issues
    Issue.all.each do |issue|
      api_calls << {
        index: {
          _index: INDEX_NAME,
          _type: :issue,
          _id:   issue.id,
        }
      }
      api_calls << {
        i_issue_id:   issue.id,
        i_user_id:    issue.user_id,
        s_title:      issue.title,
        s_body:       issue.body,
        i_created_at: issue.created_at,
      }
    end
  end

  def process_users
    User.all.each do |user|
      api_calls << {
        index: {
          _index: INDEX_NAME,
          _type: :user,
          _id:   user.id,
        }
      }

      name_ja, name_en = rand < 0.8 \
        ? [user.name_ja, nil]
        : [nil, user.name_en]

      api_calls << {
        i_user_id:          user.id,
        s_name_ja:          name_ja,
        s_name_ja_phonetic: name_ja,
        s_name_en:          name_en,
        s_username:         user.username,
        i_involved_count:   user.issues.size + user.comments.size,
        i_wantedly_score:   random_bell.rand.to_i,
        n_skill_tags:       build_skill_tags,
      }
    end
  end

  def create_users
    10000.times do
      name = Gimei.name

      User.create(
        name_ja:  name.kanji,
        name_en:  Romaji.kana2romaji(name.katakana),
        username: nil,
      )
    end
  end

  def random_bell
    @random_bell ||= RandomBell.new(mu: 40, sigma: 50, range: 0..200)
  end

  def build_skill_tags
    skill_tags = []

    if rand < 0.0005
      skill_tags << {
        s_tag_name_ja: 'Vim',
        i_endorsement_count: rand(0..10),
      }
    end
    if rand < 0.001
      skill_tags << {
        s_tag_name_ja: 'Golang',
        i_endorsement_count: rand(0..50),
      }
    end
    if rand < 0.002
      skill_tags << {
        s_tag_name_ja: 'Ruby',
        i_endorsement_count: rand(0..50),
      }
    end

    skill_tags
  end

  def api_calls
    @api_calls ||= []
  end

  def print_json
    api_calls.each do |chunk|
      puts JSON.dump(chunk)
    end
  end

end

# BatchFileCreation.new.perform!
random_bell = RandomBell.new(mu: 40, sigma: 50, range: 0..200)
puts random_bell.to_histogram
