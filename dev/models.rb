require 'json'
require 'pathname'
require 'active_hash'

class ApplicationModel < ActiveJSON::Base

  include ActiveHash::Associations

  set_root_path File.expand_path('../data', __FILE__)

  def self.dump(records)
    open(self.full_path, 'w') { |f| JSON.dump(records, f) }
  end

end

class Comment < ApplicationModel

  belongs_to :issue
  belongs_to :user

  field :body
  field :created_at

end

class Issue < ApplicationModel

  belongs_to :user
  has_many :comments

  field :title
  field :body
  field :created_at

end

class User < ApplicationModel

  has_many :issues
  has_many :comments

  field :name_en
  field :name_ja
  field :username

end
