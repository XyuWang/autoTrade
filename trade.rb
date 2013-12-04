#coding: utf-8
require './bter'
require 'chinashop'
require './log'
require 'debugger'

def get_prices bter
  print '正在获取Bter价格...'
  price = Bter.btc_price
  buy1 = price["buy"]
  sell1 = price["sell"]

  sleep 1
  price = Bter.btc_price
  buy2 = price["buy"]
  sell2 = price["sell"]

  bter_buy_price = buy1 < buy2 ? buy1 : buy2
  bter_sell_price = sell1 > sell2 ? sell1 : sell2
  puts "成功!"

  print '正在获取Btcc价格...'
  ticker = ChinaShop.ticker
  btcc_buy_price = ticker.buy.to_f
  btcc_sell_price = ticker.sell.to_f

  raise '价格错误' if !(btcc_buy_price > 0)  ||  !(btcc_sell_price > 0) || !(bter_buy_price > 0)  || !(bter_sell_price > 0)
  puts '成功!'
  return {"bter" => {"sell" => bter_sell_price, "buy" => bter_buy_price}, "btcc" => {"sell" => btcc_sell_price, "buy" => btcc_buy_price}}

rescue SystemExit, Interrupt
  raise
rescue Exception => e
  puts "获取价格发生错误：#{e} 正在重试..."
  retry
end

def trade
  bter = Bter.new '86EB2B7B-848A-423E-8E63-5FAC295193AB', '08b78689ef43f6f23deb6d2125d841e7c3cb799652137cd45501c095c2d2bbb1'

  ChinaShop.configure do |config|
    config.key = '57e46e51-8747-4159-9b1d-357e119767e1'
    config.secret = 'af46fbd8-683c-4fec-9194-c1b7b246fb85'
  end

  @if_trade = false

  @trade_spread = 30
  while true
    check_balance ChinaShop, bter if @if_trade

    prices = get_prices Bter
    bter_buy_price =  prices["bter"]["buy"]
    bter_sell_price = prices["bter"]["sell"]
    btcc_buy_price = prices["btcc"]["buy"]
    btcc_sell_price = prices["btcc"]["sell"]

    if (bter_buy_price - btcc_sell_price) > @trade_spread 
      info = "bter价格(#{bter_buy_price}) 大于 btcc价格(#{btcc_sell_price})  差价: #{ (((bter_buy_price - btcc_sell_price)*100).to_i)/100.0 }"
      puts info

      if @if_trade
        Log.info info
        # trade
        bter.sell  bter_buy_price - 5, 0.01
        info  = "Bter: 以#{bter_buy_price - 5} 卖出 0.01 B"
        puts info 
        Log.info info
        ChinaShop.buy btcc_sell_price + 5, 0.01
        info = "Btcc: 以#{btcc_sell_price + 5} 买入 0.01 B"
        puts info
        Log.info info
      end
    elsif (btcc_buy_price - bter_sell_price) > @trade_spread
      info = "btcc价格(#{btcc_buy_price}) 大于 bter价格(#{bter_sell_price})  差价: #{ (((btcc_buy_price - bter_sell_price)*100).to_i)/100.0 }"
      puts info

      if @if_trade
        Log.info info

        #trade
        bter.buy  bter_sell_price + 5, 0.01
        info  = "Bter: 以#{bter_sell_price + 5} 买入 0.01 B"
        puts info
        Log.info info
        ChinaShop.sell btcc_buy_price - 5, 0.01 #TODO 错误处理.BUG!!!
        info = "Btcc: 以#{btcc_buy_price - 5} 卖出 0.01 B"
        puts info
        Log.info info
      end
    else
      puts '..........没有发现价格差距 正在等待重试..........'
    end
  end
end

def check_balance btcc, bter
  lack_money_value = 70
  lack_btc_value = 0.01

  balance = btcc.account.balance
  money = balance.cny.to_f
  btc = balance.btc.to_f

  if money <= lack_money_value
    error = "btcc人民币余额不足 当前余额#{money}"
    raise RuntimeError, error
  end

  if btc <= lack_btc_value
    error = "btcc BTC余额不足 当前余额#{btc}"
    raise RuntimeError, error
  end

  balance = bter.balance
  money = balance['CNY']
  bter_btc = balance['BTC']

  if money <= lack_money_value
    error = "bter人民币余额不足 当前余额#{balance}"
    raise RuntimeError, error
  end

  if bter_btc <= lack_btc_value
    error = "bter BTC余额不足 当前余额#{bter_btc}"
    raise RuntimeError, error
  end

rescue RuntimeError => e
  Log.error e
  @if_retry = true
  if @if_retry
    @if_retry = false
    retry
  end
end

trade()
#TODO  分情况检测余额
#btcc buy sell错误处理
