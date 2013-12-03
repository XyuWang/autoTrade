#coding: utf-8
require './bter'
require 'chinashop'
require './log'
require 'debugger'

def trade
  bter = Bter.new '86EB2B7B-848A-423E-8E63-5FAC295193AB', '08b78689ef43f6f23deb6d2125d841e7c3cb799652137cd45501c095c2d2bbb1'

  ChinaShop.configure do |config|
    config.key = '57e46e51-8747-4159-9b1d-357e119767e1'
    config.secret = 'af46fbd8-683c-4fec-9194-c1b7b246fb85'
  end

  @trade_spread = 50

  check_balance ChinaShop, bter

  bter_buy_price =  Bter.btc_price["buy"]
  bter_sell_price =  Bter.btc_price["sell"]

  ticker = ChinaShop.ticker
  btcc_buy_price = ticker.buy.to_f
  btcc_sell_price = ticker.sell.to_f

  if !btcc_buy_price
    puts "error: #{btcc_buy_price}"
    exit
  end
  if !btcc_sell_price
    puts "error: #{btcc_sell_price}"
    exit 
  end

  if (bter_buy_price - btcc_sell_price) > @trade_spread 
    # trade
    #bter.sell
    #btcc.buy
    info = "bter价格(#{bter_buy_price}) 大于 btcc价格(#{btcc_sell_price})  差价: #{ (((bter_buy_price - btcc_sell_price)*100).to_i)/100.0 }"
    puts info
    Log.info info
  elsif (btcc_buy_price - bter_sell_price) > @trade_spread
    info = "btcc价格(#{btcc_buy_price}) 大于 bter价格(#{bter_sell_price})  差价: #{ (((btcc_buy_price - bter_sell_price)*100).to_i)/100.0 }"
    puts info
    Log.info info

    #trade
    #btcc.sell
    #bter.buy
  end
end

def check_balance btcc, bter
  lack_money_value = 10
  lack_btc_value = 0.01

  balance = btcc.account.balance
  money = balance.cny.to_f
  btc = balance.btc.to_f

  if money <= lack_money_value
    error = "btcc人民币余额不足 当前余额#{money}"
    Log.error error
    throw error
  end

  if btc <= lack_btc_value
    error = "btcc BTC余额不足 当前余额#{btc}"
    Log.error error
    throw error
  end

  money = bter.money_balance 
  bter_btc = bter.btc_balance

  if money <= lack_money_value
    error = "bter人民币余额不足 当前余额#{money}"
    Log.error error
    throw error
  end

  if bter_btc <= lack_btc_value
    error = "bter BTC余额不足 当前余额#{bter_btc}"
    Log.error error
    throw error
  end
end


trade()
