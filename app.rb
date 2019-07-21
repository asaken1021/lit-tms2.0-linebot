require 'bundler/setup'
Bundler.require
require 'sinatra/reloader' if development?

require 'line/bot'
require 'logger'
require 'json'

require 'open-uri'
require 'net/http'
require 'webrick/https'
require 'openssl'

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
  request.body.rewind
  params = JSON.parse(request.body.string)
  message = {
    type: 'text',
    text: params['message']
  }
  client.push_message(params['to'], message)
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
        if event.message['text'] == 'checkmyid'
          message = {
          type: 'text',
          text: 'あなたのユーザーID: ' + event['source']['userId']
        }
        client.reply_message(event['replyToken'], message)
        end
        if event.message['text'] = '連携'
          userID = event['source']['userId']
          linkTokenResponse = client.create_link_token(userID)
          logger.info linkTokenResponse.body
          linkToken = linkTokenResponse
          message = {
            type: 'text',
            text: 'アカウント連携URL: ' + 'https://gcp2.asaken1021.net:50001/line_link?' + linkToken
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    when Line::Bot::Event::AccountLink
      if event['link']['result'] == 'ok'
        userID = event['source']['userId']
        TMSURI = URI('https://gcp2.asaken1021.net:50001/line_link_completed')
        data = {
          nonce: event['link']['nonce'],
          userId: userID
        }.to_json
        https = Net::HTTP.new(BotURI.host, BotURI.port)
        https.use_ssl = true
        req = Net::HTTP::Post.new(BotURI)
        req.body = data
        req['Content-Type'] = "application/json"
        req['Accept'] = "application/json"
        res = https.request(req)

        message = {
          type: 'text',
          text: 'アカウント連携が正常に完了しました。'
        }
        client.reply_message(event['replyToken'], message)
      end
    end
  end
  'OK'
end