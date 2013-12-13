#encoding: utf-8
#
# Usage:
# b = Bter.new key, secret
# b.balance
#
# Bter.btc_price => {"avg"=>6582.07, "sell"=>6300, "buy"=>6270}"
# Bter.debug = true/false
# Bter.retry_limit = 3
# b.buy 8000, 0.1
# b.sell 8000, 0.1
#
require './log'
require 'json'
require 'digest/sha2'
require 'digest/hmac'
require 'rest_client'
require 'debugger'

class Bter
  class << self
    def debug= debug
      @debug = debug
    end

    def debug
      @debug || false
    end

    def retry_limit= times
      @retry_limit = times
    end

    def retry_limit
      @retry_limit || 3 # default: 3
    end

    def configure
      yield self
    end
  end

  def initialize key, secret
    @key = key
    @secret = secret

    @balance_address = 'https://bter.com/api/1/private/getfunds'
    @place_order_address = 'https://bter.com/api/1/private/placeorder'
  end

  def self.btc_price
    btc_orders_address = 'https://bter.com/api/1/depth/btc_cny'

    resource = RestClient::Resource.new(btc_orders_address, :open_timeout => 15, timeout: 15)
    res = resource.get

    result = JSON.parse res.to_str

    if result['result'] != 'true' || !result['bids'] || !result['asks'] || result['bids'].size == 0 || result['asks'].size == 0
      raise '无法从Bter获取价格信息'
    end

    sell_price = result['asks'].last[0]
    buy_price = result['bids'][0][0]

    if sell_price < buy_price
      raise "价格异常..卖价:#{sell_price} 买价#{buy_price}"
    end

    return {"sell"=> sell_price, 'buy' => buy_price}
  rescue Exception => e
    print "Bter: 无法获取价格信息 #{e}" if Bter.debug

    retry_times += 1
    puts "正在重试..." if Bter.debug
    sleep 1
    retry
  end

  def buy price, amount
    place_order price, amount, "BUY"
  end

  def sell price, amount
    place_order price, amount, "SELL"
  end

  def balance
    print '正在获取Bter余额信息...' if Bter.debug
    result = post @balance_address, ''

    if result['result'] != 'true'
      raise '无法从Bter获取价格信息  ' + result['message']
    end

    funds = result['available_funds']

    raise 'Bter:获取余额失败!'  if funds.size == 0

    puts "成功!" if Bter.debug

    return {'BTC' => funds['BTC'].to_f, 'CNY' => funds['CNY'].to_f }

  rescue SystemExit, Interrupt
    raise
  rescue Exception => e
    puts "Bter: 无法获取价格信息#{e} 正在重试..." if Bter.debug

    retry_times += 1
    puts "正在重试..." if Bter.debug
    retry
  end

  private
  def get_sign params
    Digest::HMAC.hexdigest(params, @secret, Digest::SHA512)
  end

  def post url, data
#    result = RestClient.post url, data,  'KEY' => @key, 'SIGN' => get_sign(data), timeout
    resource = RestClient::Resource.new(url, :open_timeout => 15, timeout: 15)
    result = resource.post data,  'KEY' => @key, 'SIGN' => get_sign(data)

    JSON.parse result.to_str
  end

  def place_order price, amount, type
    retry_times ||= 0

    res = post @place_order_address, URI.encode_www_form(pair: "btc_cny", type: type, rate: price, amount: amount)
    if !res || res['result'] != true
      raise  "在Bter#{type}比特币失败 原因：#{res["msg"]}"
    end

    return res

  rescue Exception => e
    puts e if Bter.debug
    Log.error e

    if retry_times < Bter.retry_limit
      retry_times += 1
      info = "正在重试..."
      puts info if Bter.debug
      Log.info info
      retry
    else
      raise e
    end
  end
end

=begin
b = Bter.new '86EB2B7B-848A-423E-8E63-5FAC295193AB', '08b78689ef43f6f23deb6d2125d841e7c3cb799652137cd45501c095c2d2bbb1'
Bter.debug = true
puts b.balance

puts Bter.btc_price
#debugger
a = 10
=end
