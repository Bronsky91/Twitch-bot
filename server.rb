require 'sinatra'
require 'mongoid'
require 'sinatra/namespace'
require 'sinatra/cross_origin'
require './bot'
require "rubygems"
require "sinatra/base"


# DB Setup
Mongoid.load! "mongoid.config"

# Models
class GameId
    include Mongoid::Document

    field :game_id, type: Integer
    field :blue_team, type: String
    field :red_team, type: String
    field :game_started, type: Boolean, default: false

    validates :game_id, presence: true

    index({ game_id:1 }, { unique: true, name: 'game_id_index' })
end

class PotgVote
    include Mongoid::Document

    field :game_id, type: Integer
    field :username, type: String
    field :vote, type: String
    field :timestamp, type: Integer

    validates :game_id, presence: true
    validates :username, presence: true
    validates :vote, presence: true
    validates :timestamp, presence: true
end

class TeamVote
    include Mongoid::Document

    field :game_id, type: Integer
    field :username, type: String
    field :vote, type: String

    validates :game_id, presence: true
    validates :username, presence: true
    validates :vote, presence: true

    scope :game_id, -> (game_id) { where(game_id: game_id) }
end


# Serializers
class GameIdSerializer
    def initialize(game_id)
    @game_id = game_id
    end

    def as_json(*)
    data = {
        id:@game_id.id.to_s,
        game_id:@game_id.game_id,
        blue_team:@game_id.blue_team,
        red_team:@game_id.red_team,
        game_started:@game_id.game_started
    }
    data[:errors] = @game_id.errors if@game_id.errors.any?
        data
    end
end


class TeamVoteSerializer
    def initialize(team_vote)
    @team_vote = team_vote
    end

    def as_json(*)
    data = {
        id:@team_vote.id.to_s,
        game_id:@team_vote.game_id,
        username:@team_vote.username,
        vote:@team_vote.vote
    }
    data[:errors] = @team_vote.errors if@team_vote.errors.any?
    data
    end
end


class PotgVoteSerializer
    def initialize(potg_vote)
        @potg_vote = potg_vote
    end

    def as_json(*)
        data = {
        id:@potg_vote.id.to_s,
        game_id:@potg_vote.game_id,
        username:@potg_vote.username,
        vote:@potg_vote.vote,
        timestamp:@potg_vote.timestamp
        }
        data[:errors] = @potg_vote.errors if @potg_vote.errors.any?
        data
    end
end

configure do
    enable :cross_origin
    enable :sessions
end

before do
    response.headers['Access-Control-Allow-Origin'] = '*'
end

get '/' do
    @game = GameId.last
    if @game == nil
        GameId.create(game_id:0,game_started:false)
        @game = GameId.last
    end
    erb :twitchbot
end

post '/setmatch' do 
    game = GameId.last
    game.update_attributes(
        blue_team: params[:blue_team].delete(' ').upcase(),
        red_team: params[:red_team].delete(' ').upcase()
    )
    redirect '/'
end

post '/load' do
    # Creates Bot
    
end

post '/bot' do
    bot = TwitchBot.new
    if params[:run]
        bot.run
    elsif params[:quit]
        bot.quit
    elsif params[:new_game]
        bot.new_game
        game = GameId.last
        game.update_attributes(
            blue_team: params[:blue_team].delete(' ').upcase(),
            red_team: params[:red_team].delete(' ').upcase())
    elsif params[:end_game]
        bot.end_game
    end
    redirect '/'
end

namespace '/api/v1' do

    before do
        content_type 'application/json'
    end
    
    # /api/v1/gameid
    get '/gameid' do
        game_id = GameId.last
        GameIdSerializer.new(game_id).to_json
    end

    # /api/v1/teamvotes/{game_id}
    get '/teamvotes/:game_id' do |game_id|
        teamvotes = TeamVote.where(game_id: game_id)

        teamvotes.map { |team_vote| TeamVoteSerializer.new(team_vote) }.to_json
    end

    # /api/v1/playofthegame/{game_id}
    get '/playofthegame/:game_id' do |game_id|
        potgvotes = PotgVote.where(game_id: game_id)

        potgvotes.map { |potg_vote| PotgVoteSerializer.new(potg_vote) }.to_json
    end

end