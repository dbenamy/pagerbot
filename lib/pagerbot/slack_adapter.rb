require 'json'
require 'sinatra/base'
require 'slack-ruby-client'

module PagerBot
  class SlackAdapter
    def self.run!
      PagerBot::SlackAdapter.new().run()
    end

    def initialize
      Slack.configure do |config|
        config.token = configatron.bot.slack.api_token
      end
      @rtm_client = Slack::RealTime::Client.new
      @rtm_client.on :hello do
        @bot_user_id = @rtm_client.self.id
        puts ("Successfully connected, welcome '#{@rtm_client.self.name}' to " +
          "the '#{@rtm_client.team.name}' team at " +
          "https://#{@rtm_client.team.domain}.slack.com.")
      end
      @rtm_client.on :message do |data|
        process_message(data)
      end
    end

    def run
      @rtm_client.start!
    end

    def process_message(data)
      return if data.type != 'message'
      return if data.subtype == 'bot_message'
      user_id = data.user
      user_name = @rtm_client.users.fetch(user_id).name
      channel_id = data.channel
      channel_name = @rtm_client.channels.fetch(channel_id).name
      return unless configatron.bot.all_channels ||
        configatron.bot.channels.include?(channel_name)
      text = Slack::Messages::Formatting.unescape(data.text)
      text.gsub!(/\A@#{@bot_user_id}/, "@#{configatron.bot.name}")
      return unless text.match(%r{@?#{configatron.bot.name}[: ]})
      PagerBot.log.info("Message: #{text} by #{user_name} in ##{channel_name}")

      params = {
        nick: user_name,
        channel_name: channel_name,
        text: text,
        user_id: user_id,
        adapter: :slack
      }
      answer = PagerBot.process(params[:text], params)

      if answer[:private_message]
        send_message(answer.fetch(:private_message), user_id)
      end
      if answer[:message]
        send_message(answer.fetch(:message), channel_id)
      end
      nil
    end

    def send_message(message, to)
      icon_emoji = configatron.bot.slack.emoji || ":frog:"
      resp = @rtm_client.web_client.chat_postMessage(
        channel: to, text: message, username: configatron.bot.name,
        icon_emoji: icon_emoji)
      PagerBot.log.info resp
    end
  end
end
