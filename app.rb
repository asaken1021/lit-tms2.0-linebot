require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?

require 'line/bot'
require 'logger'

get '/' do
  erb :index
end

def client
  @client ||= Line::Bot::Client.new {|config|
    config.channel_secret = ENV['LINE_CHANNEL_SECRET']
    config.channel_token = ENV['LINE_CHANNEL_TOKEN']
  }
end

post '/send_notify' do
  params = JSON.parse(request.body.read)
  message = {
    type: 'text',
    text: params[:message]
  }
  client.push_message(params[:to], message)
  logger.info request.body.read
  logger.info params[:to]
  logger.info message
end

post '/webhook' do
  body = request.body.read

  signature = request.env['HTTP_X_LINE_SIGNATURE']
  unless client.validate_signature(body, signature)
    error 400 do 'Bad Request' end
  end

  events = client.parse_events_from(body)
  events.each do |event|
    case event
    when Line::Bot::Event::Message
      case event.type
      when Line::Bot::Event::MessageType::Text
        message = {
          type: 'text',
          text: event.message['text'] + ' UserID:' + event['source']['userId']
        }
        client.reply_message(event['replyToken'], message)
      end
    end
  end
  'OK'
end