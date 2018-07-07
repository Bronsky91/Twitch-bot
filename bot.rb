require 'socket'
require 'mongoid'
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


    def run
        @game_id = Time.now.to_i
        GameId.create(game_id:@game_id)
        write_to_chat "Caster_Bot Online"
        potg_arr = []
        
        until @socket.eof? do
            message = @socket.gets

            if message.match(/^PING :(.*)$/)
                write_to_system "PONG #{$~[1]}"
                next
            end

            if message.match(/PRIVMSG ##{@channel} :(.*)$/)
                content = $~[1]
                username = message.match(/@(.*).tmi.twitch.tv/)[1]

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
                end
                
            end
        end
    end


    def quit
        write_to_chat "Caster_Bot is Offline"
        write_to_system "PART ##{@channel}"
        write_to_system "QUIT"
    end

end

