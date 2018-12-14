# coding: utf-8
require 'slack-ruby-bot'
require 'mini_magick'
require 'faraday'
require "fileutils"
require 'securerandom'

# slackAPIのトークン
TOKEN = "xoxb-123456789012-123456789012-XXXXXXXXXXXXXXXXXXXXXXXX"

# テーマ表示用のベースとなる画像のパス名
BASE_IMAGE_PATH = './waku.jpg'

# slackに表示させる画像を置くディレクトリのサーバ上のパス名
OUTPUT_IMAGE_PATH = '/var/www/html/img/'

# 上記で配置する画像を表示するためのURL
DISPLAY_IMAGE_URL = 'http://example.com/img/'

# mini_magic用の設定値
GRAVITY = 'center'
TEXT_POSITION = '0,0'
FONT = './YOURFONT.ttf' # トークテーマ表示用のフォントのパス名
FONT_SIZE = 65
INDENTION_COUNT = 11
ROW_LIMIT = 8

# botの名前
BOT_NAME = 'botname'

# Logの出力レベルの設定
SlackRubyBot::Client.logger.level = Logger::WARN

class Bot
  # 生成したGif動画用にuniqなファイル名を返却
  def uniq_file_name
     "#{SecureRandom.hex}.gif"
  end

  def call(client, data)
    case 
    when data.text == "dice del" then
      # 自分のユーザID取得
      members = client.web_client.users_list(
        channel: data.channel, 
      ).members
      members.each do |mem|
        if mem.name == BOT_NAME
          @userid = mem.id
        end
      end
      @history = client.web_client.channels_history(
        channel: data.channel, 
        oldest: (Time.now - (60 * 60 * 24)).to_i,
        count: 1000
      )
      i = 0
      @history.messages.each do |his|
        if i > 3 then
          break
        end
        if his.user == @userid || his.text == 'えいっ！'
          client.web_client.chat_delete(
            channel: data.channel, 
            ts: his.ts
          )
          i += 1
        end
      end

    when data.text == "dice list" then
      client.say(
        as_user: false,
        text: "登録されているトークテーマの一覧です。", 
        channel: data.channel,
      )
      d = File.read("data.txt")
      client.say(
        as_user: false,
        text: d, 
        channel: data.channel,
      )

    when data.text == "dice go" then
      Dir.glob(OUTPUT_IMAGE_PATH + '*.gif').each do |filename|
          FileUtils.rm(filename)
      end
      arr = File.open('data.txt').readlines
      client.say(
        as_user: false,
        text: "サイコロスタート！ちょっとまってね。", 
        channel: data.channel,
      )
      num = Dir.glob("./images/0*").count
      file_name = uniq_file_name

      # 後半部分のGIFアニメ作成
      MiniMagick::Tool::Convert.new do |convert|
        convert.layers 'optimize'
        convert.delay 40
        5.times do
          @fn = SecureRandom.random_number(num) + 1
          convert << "./images/" + sprintf("%03d",@fn) + ".png"
        end
        @result = @fn
        #puts @result
        convert << "./images/temp2.gif" 
      end

      MiniMagick::Tool::Convert.new do |convert|
        convert.layers 'optimize'
        convert.loop 1
        convert.delay 10
        convert << './images/temp1.gif'
        convert.delay 50
        convert << './images/temp2.gif'
        convert << OUTPUT_IMAGE_PATH + file_name 
      end

      client.web_client.chat_postMessage(
        as_user: false,
        text: "えいっ！", 
        channel: data.channel, 
        username: 'サイコロトークbot',
        icon_url: DISPLAY_IMAGE_URL + "/throw.png",
      )

      url = DISPLAY_IMAGE_URL + file_name
      res = client.web_client.chat_postMessage(
        as_user: true,
        text: url, 
        channel: data.channel, 
      )
      @ts =  res.ts
      sleep(8)
      if @ts != nil
        client.web_client.chat_delete(
          channel: data.channel, 
          ts: @ts
        )
      end
      client.say(
        text: '*' + arr[@result - 1].chomp + '!!!*', 
        channel: data.channel,
      )
     when data.text == "dice help" then
      help = "```登録済みのトークテーマの中からランダムに１つ選びます。\n
      コマンド名     説明
      ------------------------------------------------------------
      dice help     このヘルプを表示します。
      dice list     登録済みのトークテーマを一覧表示します。
      dice go       サイコロを振ります。
      dice del      サイコロトークbotの発言を３件削除します。
      dice update   トークテーマを更新します(下記参照)。
      ------------------------------------------------------------
      トークテーマの更新方法
      1行目に dice update を、2行目以下にテーマを改行区切りで入力後、送信します。
      ※既存のリストは削除されます。
      例)
      dice update
      テーマ１
      テーマ２
      テーマ３
      　 ：
      　 ：
      ```"
      client.say(
        text: help, 
        channel: data.channel,
      )

    when data.text != nil && data.text.start_with?("dice update") then
      FileUtils.rm(Dir.glob('images/*.*'))
      # data.textの内容を改行区切りで配列に格納
      lines = data.text.rstrip.split(/\r?\n/).map {|line| line.chomp }
      lines = lines.drop(1)
      # 配列の内容をdata.txtファイルに出力
      File.open("data.txt", "w") do |f|
          lines.each { |s| f.puts(s) }
      end
      # GIFアニメ作成
      ImageHelper.write
      client.say(
        text: "登録が完了しました。", 
        channel: data.channel,
      )
    end
  end
end

class ImageHelper

  class << self
    # 合成後のFileClassを生成
    def build(text)
      text = prepare_text(text)
      @image = MiniMagick::Image.open(BASE_IMAGE_PATH)
      configuration(text)
    end

    # 前半部分のGIFアニメ作成
    def write
      # data.txtを読み込みそれぞれのテーマの画像を生成
      File.open('data.txt') do |file|
        i = 1
        file.each_line do |line|
          build(line)
          @image.write "./images/" + sprintf("%03d",i) + ".png"
          #puts labmen
          puts line
          i += 1
        end
      end

      # 生成した画像でGIFアニメ作成
      MiniMagick::Tool::Convert.new do |convert|
        convert.layers 'optimize'
        convert.loop 2
        convert.delay 10
        Dir.glob('./images/0*').shuffle.each do|f|
          convert << f
        end
        convert << './images/temp1.gif'
      end
    end

    private

    # 設定関連の値を代入
    def configuration(text)
      @image.combine_options do |config|
        config.font FONT
        config.gravity GRAVITY
        config.pointsize FONT_SIZE
        config.draw "text #{TEXT_POSITION} '#{text}'"
      end
    end

    # 背景にいい感じに収まるように文字を調整して返却
    def prepare_text(text)
      text.scan(/.{1,#{INDENTION_COUNT}}/)[0...ROW_LIMIT].join("\n")
    end
  end
end

# Slack-Ruby-Botのログをファイルに出力する
SlackRubyBot.configure do |config|
  config.logger = Logger.new("slack-ruby-bot.log", "daily")
end

server = SlackRubyBot::Server.new(
  token: TOKEN,
  hook_handlers: {
    message: Bot.new
  }
)
server.run
