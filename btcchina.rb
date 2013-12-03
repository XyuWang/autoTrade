
require './log'
require 'json'
require 'rest-open-uri'
require 'digest/sha2'
require 'digest/hmac'
require 'debugger'
require "base64"


class Btcchina
  def initialize key, secret
    @key = key
    @secret = secret
    @trade_url = 'api.btcchina.com/api_trade_v1.php'
  end

  def get_account_info
    request 'getAccountInfo', ""
  end

  def buy

  end

  def sell

  end

  def btc_price

  end

  private
  def sign params
    Digest::HMAC.hexdigest(params, @secret, Digest::SHA1)
  end

  def request method, params
    debugger
    tonce = millisecond
    body = URI.encode_www_form tonce: tonce, accesskey: @key, requestmethod: "post", id: tonce, method: method.to_s, params: params.to_s
    hash = sign body

    auth = Base64.strict_encode64("#{@key}:#{hash}")

#    url = "https://" + @key + ":" + hash + "@" + @trade_url
    url = "https://api.btcchina.com/api_trade_v1.php"
    open url, method: :post, 'Content-Type' => 'application/json-rpc',
      'Authorization' => "Basic #{auth}",
      'Json-Rpc-Tonce' => "#{tonce}"

#"Json-Rpc-Tonce" => tonce, "Authorization" => "Basic " + encode
    #, http_basic_authentication: [@key, hash]

#  rescue Exception => e
#    puts e and Log.error e
  end

  def millisecond
    ((Time.now.to_f) * 1000000).to_i.to_s
  end
end

site = Btcchina.new "035d1452-2ce3-48ea-8676-6971ac7d4dd1", "d8b408a9-8cad-4bcd-a928-131303c684a7"

site.get_account_info
