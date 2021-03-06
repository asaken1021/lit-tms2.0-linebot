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
require 'resolv'

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
  if request.ip == Resolv.getaddress('vuejs.tms.asaken1021.net')
    request.body.rewind
    params = JSON.parse(request.body.string)
    message = {
      type: 'text',
      text: params['message']
    }
    client.push_message(params['to'], message)
  else
    status 400
    body 'Bad Request'
  end
end

post '/send_notify_progress_image' do
  if request.ip == Resolv.getaddress('vuejs.tms.asaken1021.net')
    request.body.rewind
    params = JSON.parse(request.body.string)
    message = {
      type: 'image',
      originalContentUrl: params['originalUrl'],
      previewImageUrl: params['previewUrl']
    }
    client.push_message(params['to'], message)
  else
    status 400
    body 'Bad Request'
  end
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
        if event.message['text'] == '連携'
          userID = event['source']['userId']
          linkTokenResponse = client.create_link_token(userID)
          linkToken = JSON.parse(linkTokenResponse.body)['linkToken']
          message = {
            type: 'text',
            text: 'アカウント連携URL: ' + 'https://vuejs.tms.asaken1021.net/line_link?link_token=' + linkToken
          }
          client.reply_message(event['replyToken'], message)
        end
      end
    when Line::Bot::Event::AccountLink
      if event['link']['result'] == 'ok'
        userID = event['source']['userId']
        TMSURI = URI('https://vuejs.tms.asaken1021.net/line_link')
        data = {
          nonce: event['link']['nonce'],
          user_id: userID
        }.to_json
        https = Net::HTTP.new(TMSURI.host, TMSURI.port)
        https.use_ssl = true
        https.verify_mode = OpenSSL::SSL::VERIFY_NONE
        req = Net::HTTP::Put.new(TMSURI)
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