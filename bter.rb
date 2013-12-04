#encoding: utf-8
# 
# Usage:
# b = Bter.new key, secret
# b.btc_balance
# b.money_balance
#
# Bter.btc_price => {"avg"=>6582.07, "sell"=>6300, "buy"=>6270}"
#
require './log'
require 'json'
require 'rest-open-uri'
require 'digest/sha2'
require 'digest/hmac'
require 'rest_client'
require 'debugger'

class Bter
  @btc_price_address = 'https://bter.com/api/1/ticker/btc_cny'

  def initialize key, secret
    @key = key
    @secret = secret

    @balance_address = 'https://bter.com/api/1/private/getfunds'
    @place_order_address = 'https://bter.com/api/1/private/placeorder'
  end

  def self.btc_price
    res = RestClient.get @btc_price_address

    if res.code != 200
      error = '连接Bter网站失败'
      Log.error error
      raise error
    end

    result = JSON.parse res.to_str

    if result['result'] != 'true' || !result['avg'] || !result['sell'] || !result['buy'] || result['avg'] <= 0 || result['sell'] <= 0 || result['buy'] <= 0
      error = '无法从Bter获取价格信息'
      Log.error error
      raise error
    end

    return {"avg" => result['avg'], "sell"=> result['sell'], 'buy' => result['buy']}
  end

  def buy price, amount
    res = post @place_order_address, URI.encode_www_form(pair: "btc_cny", type: "BUY", rate: price, amount: amount)
    if !res || res['result'] != true
      error = "在Bter买比特币失败 原因：#{res["msg"]}"
      Log.error error
      raise error
    end
    res
  end

  def sell price, amount
    res = post @place_order_address, URI.encode_www_form(pair: "btc_cny", type: "SELL", rate: price, amount: amount)

    if !res || res['result'] != true
      error = "在Bter买比特币失败 原因：#{res['msg']}"
      Log.error error
      raise error
    end
    res
  end

  def balance
    print '正在获取Bter余额信息...'
    result = post @balance_address, ''

    if result['result'] != 'true'
      raise '无法从Bter获取价格信息  ' + result['message']
    end

    funds = result['available_funds']
    if funds.size == 0
      raise 'Bter:获取余额失败!'
    end

    puts "成功!"

    return {'BTC' => funds['BTC'].to_f, 'CNY' => funds['CNY'].to_f }

  rescue SystemExit, Interrupt
    raise
  rescue Exception => e
    error = "Bter: 无法获取价格信息#{e} 正在重试..."
    puts error
    Log.error error
    Log.error e
    retry
  end

  private
  def get_sign params
    Digest::HMAC.hexdigest(params, @secret, Digest::SHA512)
  end

  def post url, data
    # TODO 超时处理
    result = RestClient.post url, data,  'KEY' => @key, 'SIGN' => get_sign(data)
    if result.code != 200
      raise '连接Bter网站失败'
    end

    JSON.parse result.to_str
  end
end

=begin
b = Bter.new '86EB2B7B-848A-423E-8E63-5FAC295193AB', '08b78689ef43f6f23deb6d2125d841e7c3cb799652137cd45501c095c2d2bbb1'
puts b.balance
puts b.money_balance
puts b.btc_balance
puts Bter.btc_price
debugger
a = 10
=end
