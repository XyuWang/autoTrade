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
require 'debugger'

class Bter
  @btc_price_address = 'https://bter.com/api/1/ticker/btc_cny'

  def initialize key, secret
    @key = key
    @secret = secret

    @balance_address = 'https://bter.com/api/1/private/getfunds'
  end

  def btc_balance
    b = balance['available_funds']
    btc = b.size != 0 ? b['BTC'] : nil
    btc ? btc.to_f : 0.0
  end

  def money_balance
#    params = URI.encode_www_form 'a'=> 1
#    sign = get_sign params
    b = balance['available_funds']
    money = (b.size != 0) ? b['CNY'] : nil
    money ? money.to_f : 0.0
  end

  def self.btc_price
    site = open @btc_price_address

    if !site || site.status[0] != '200'
      raise 'Bter连接网站失败'
    end

    result = JSON.parse site.string

    if result['result'] != 'true' || !result['avg'] || !result['sell'] || !result['buy'] || result['avg'] <= 0 || result['sell'] <= 0 || result['buy'] <= 0
      raise '无法从Bter获取价格信息'
    end

    return {"avg" => result['avg'], "sell"=> result['sell'], 'buy' => result['buy']}
  rescue Exception => e
    puts e and Log.error e
  end

  private
  def get_sign params
    Digest::HMAC.hexdigest(params, @secret, Digest::SHA512)
  end

  def balance
    site = open @balance_address, 'KEY' => @key, :method => :post, 'SIGN' => get_sign('')

    if !site || site.status[0] != '200'
      raise '连接Bter网站失败'
    end

    result = JSON.parse site.string

    if result['result'] != 'true' 
      raise '无法从Bter获取价格信息  ' + result['message']
    end

    return result

  rescue Exception => e
    puts e and Log.error e
  end
end

=begin test
b = Bter.new '86EB2B7B-848A-423E-8E63-5FAC295193AB', '08b78689ef43f6f23deb6d2125d841e7c3cb799652137cd45501c095c2d2bbb1'
puts b.money_balance
puts b.btc_balance
puts Bter.btc_price
=end
