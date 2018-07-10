require 'socket'
require 'mongoid'
require 'securerandom'
require './server'

# DB Setup
Mongoid.load! "mongoid.config"

TWITCH_HOST = "irc.twitch.tv"
TWITCH_PORT = 6667

class TwitchBot

    def initialize
        @nickname = "Caster_Bot"
        @password = "oauth:1lj5phoisvublum26dxx1cbl1xyg4y"
        @channel = "bronsky91"
        @socket = TCPSocket.open(TWITCH_HOST, TWITCH_PORT)

        write_to_system "PASS #{@password}"
        write_to_system "NICK #{@nickname}"
        write_to_system "USER #{@nickname} 0 * #{@nickname}"
        write_to_system "JOIN ##{@channel}"
    end


    def write_to_system(message)
        @socket.puts message
    end


    def write_to_chat(message)
        write_to_system "PRIVMSG ##{@channel} :#{message}"
    end

    def new_game
        @game_id = Time.now.to_i
        GameId.create(game_id:@game_id, game_started:true)
        write_to_chat "Vote for the team you think will win anytime by using the \"!team \" command followed by the team's name!"
    end

    def end_game
        game = GameId.last
        game.update_attributes(game_id:game.game_id, game_started:false)
        write_to_chat "Voting has stopped until next game"
    end

    def run
        write_to_chat "Caster_Bot is listening"
        until @socket.eof? do
            message = @socket.gets
            game = GameId.last

            if message.match(/^PING :(.*)$/)
                write_to_system "PONG #{$~[1]}"
                next
            end

            if message.match(/PRIVMSG ##{@channel} :(.*)$/)
                content = $~[1]
                username = message.match(/@(.*).tmi.twitch.tv/)[1]

                if content.include? 'clean' or content.include? 'house'
                    write_to_chat 'Did someone say a CLEAN HOUSE!?!'
                end

                if game.game_started
                    @game_id = game.game_id
                    # ! Commands
                    if content.start_with? '!potg '
                        vote = content.split(' ')
                        vote.shift
                        vote = vote.join('').upcase
                        timestamp = Time.now.to_i
                        current_vote = PotgVote.where(game_id: @game_id, username: username).first
                        if current_vote
                            current_vote.update_attributes(game_id: @game_id, username: username, vote: vote, timestamp: timestamp)
                        else
                            PotgVote.create(game_id: @game_id, username: username, vote: vote, timestamp: timestamp)
                        end
                    elsif content.start_with? '!team '
                        vote = content.split(' ')
                        vote.shift
                        vote = vote.join('').upcase
                        current_vote = TeamVote.where(game_id: @game_id, username: username).first
                        if current_vote
                            current_vote.update_attributes(game_id: @game_id, username: username, vote: vote)
                        else
                            TeamVote.create(game_id: @game_id, username: username, vote: vote)
                        end
                    elsif content.start_with? '!teams'
                        write_to_chat "On the Blue Team we have #{game.blue_team} and on the Red Team we have #{game.red_team}"
                    end
                end
            end
            sleep(0.5)
        end
    end


    def quit
        write_to_chat "Caster_Bot is Offline"
        write_to_system "PART ##{@channel}"
        write_to_system "QUIT"
    end

end

