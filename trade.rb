#coding: utf-8
require './bter'
require 'chinashop'
require './log'
require 'debugger'

class LackMoneyException < RuntimeError
end

class Trade
  attr_accessor :debug, :price_spread, :retry_limit, :piece,
    :bter_cny_balance, :bter_btc_balance, :bter_buy_price, :bter_sell_price,
    :btcc_cny_balance, :btcc_btc_balance, :btcc_buy_price, :btcc_sell_price


  def initialize bter, btcc
    @bter = bter
    @btcc = btcc

    #default:
    self.price_spread = 50
    self.retry_limit = 3
    self.debug = false
    self.piece = 0.01
  end

  def set_prices
    retry_times ||= 0

    print '正在获取价格信息...' if debug
#    print '正在获取Bter价格...' if debug
    price = Bter.btc_price
    self.bter_buy_price = price["buy"]
    self.bter_sell_price = price["sell"]

#    puts "成功!" if debug

#    print '正在获取Btcc价格...' if debug
    ticker = ChinaShop.ticker
    self.btcc_buy_price = ticker.buy.to_f
    self.btcc_sell_price = ticker.sell.to_f

    raise '价格错误' if !(self.btcc_buy_price > 0)  || !(self.btcc_sell_price > 0) || !(self.bter_buy_price > 0)  || !(self.bter_sell_price > 0)
    puts '成功!' if debug

  rescue SystemExit, Interrupt
    raise
  rescue Exception => e
    error = "获取价格发生错误：#{e}"
    puts error if debug

    if retry_times < retry_limit
      retry_times += 1
      puts "正在重试..." if debug
      retry
    else
      raise
    end
  end

  def set_balances
    retry_times ||= 0

    print '正在获取余额信息...' if debug
#    print '正在获取btcc余额信息...' if debug

    balance = @btcc.account.balance
    self.btcc_cny_balance = balance.cny.to_f
    self.btcc_btc_balance = balance.btc.to_f

#    print '正在获取bter余额信息...' if debug

    balance = @bter.balance
    self.bter_cny_balance = balance['CNY']
    self.bter_btc_balance = balance['BTC']
    puts "成功!" if debug

  rescue SystemExit, Interrupt
    raise
  rescue Exception => e
    error = "获取余额发生错误：#{e}"
    puts error if debug

    if retry_times < retry_limit
      retry_times += 1
      puts "正在重试..." if debug
      retry
    else
      raise
    end
  end

  def start
    while true

      set_balances
      set_prices

      if btcc_buy_price > bter_sell_price +  price_spread
        spread = btcc_buy_price - bter_sell_price
        info = "btcc价格(#{btcc_buy_price}) 大于 bter价格(#{bter_sell_price})  差价: #{ simplify(spread)}"
        puts info
        Log.info info

        puts '检测是否可以交易' if debug

        if btcc_btc_balance > piece && bter_cny_balance > bter_sell_price * piece
          info = '----------准备交易----------'
          puts info
          Log.info info

          #trade:
          btcc_retry_times = 0
          bter_retry_times = 0

          begin
            result = @btcc.sell price: btcc_buy_price - 5, amount: piece
            if !result || result.result != true
              raise '于BTCC卖出BTC 失败'
            end

            info = "Btcc 以价格(#{btcc_buy_price - 5}) 卖出 #{piece} BTC"
            Log.info info

          rescue Exception => e
            error = "btcc交易发生异常:#{e}"
            puts error
            Log.error error

            info =  '正在确认是否已经完成交易'
            puts info
            Log.info info

            if finish_btcc_trade?
              info = 'btcc已经完成交易 交易继续'
              puts info
              Log.info info
            else
              error = 'btcc 未完成交易..'
              puts error
              Log.info error

              if btcc_retry_times < retry_limit
                info = '正在重试...'
                puts info if debug
                Log.info info
                btcc_retry_times += 1
                retry
              else
                raise
              end
            end
          end

          begin
            @bter.buy bter_sell_price + 5, piece

            info = "Bter 以价格(#{bter_sell_price + 5}) 买入 #{piece} BTC"
            Log.info info
          rescue Exception => e
            error = "bter交易发生异常:#{e}"
            puts error
            Log.error error

            info =  '正在确认是否已经完成交易'
            puts info
            Log.info info

            if finish_bter_trade?
              info = 'bter已经完成交易 交易继续'
              puts info
              Log.info info
            else
              error = 'bter 未完成交易..'
              puts error
              Log.info error

              if btcc_retry_times < retry_limit
                info = '正在重试...'
                puts info if debug
                Log.info info
                btcc_retry_times += 1
                retry
              else
                raise
              end
            end
          end

          info = '----------结束交易----------'
          puts info
          Log.info info
        else
          error =  "余额不足 btcc[cny: #{btcc_cny_balance}, btc: #{ btcc_btc_balance}]  bter[cny: #{bter_cny_balance}, btc: #{bter_btc_balance}]"
          raise LackMoneyException, error
        end

      elsif bter_buy_price > btcc_sell_price + price_spread
        info = "bter价格(#{bter_buy_price}) 大于 btcc价格(#{btcc_sell_price})  差价: #{ simplify(bter_buy_price - btcc_sell_price) }"
        puts info
        Log.info info


        puts '检测是否可以交易' if debug

        if bter_btc_balance > piece && btcc_cny_balance > btcc_sell_price * piece
          info = '----------准备交易----------'
          puts info
          Log.info info

          #trade:
          btcc_retry_times = 0
          bter_retry_times = 0

          begin
            @bter.sell bter_buy_price - 5, piece
            info = "Bter 以价格(#{bter_buy_price - 5}) 卖出 #{piece} BTC"
            Log.info info
          rescue Exception => e
            error = "bter交易发生异常:#{e}"
            puts error
            Log.error error

            info =  '正在确认是否已经完成交易'
            puts info
            Log.info info

            if finish_bter_trade?
              info = 'bter已经完成交易 交易继续'
              puts info
              Log.info info
            else
              error = 'bter 未完成交易..'
              puts error
              Log.info error

              if bter_retry_times < retry_limit
                info = '正在重试...'
                puts info if debug
                Log.info info
                bter_retry_times += 1
                retry
              else
                raise
              end
            end
          end

          begin
            result = @btcc.buy price: btcc_sell_price + 5, amount: piece
            if !result || result.result != true
              raise '于BTCC买入BTC 失败'
            end

            info = "Btcc 以价格(#{btcc_sell_price + 5}) 买入 #{piece} BTC"
            Log.info info

          rescue Exception => e
            error = "btcc交易发生异常:#{e}"
            puts error
            Log.error error

            info =  '正在确认是否已经完成交易'
            puts info
            Log.info info

            if finish_btcc_trade?
              info = 'btcc已经完成交易 交易继续'
              puts info
              Log.info info
            else
              error = 'btcc 未完成交易..'
              puts error
              Log.info error

              if btcc_retry_times < retry_limit
                btcc_retry_times += 1
                info = '正在重试...'
                puts info if debug
                Log.info info
                retry
              else
                raise
              end
            end
          end

          info = '----------结束交易----------'
          puts info
          Log.info info
        else
          error =  "余额不足 btcc[cny: #{btcc_cny_balance}, btc: #{ btcc_btc_balance}]  bter[cny: #{bter_cny_balance}, btc: #{bter_btc_balance}]"
          raise LackMoneyException, error
        end

      else
        puts '..........没有发现价格差距 正在等待重试..........' if debug
      end

    end
  rescue SystemExit, Interrupt
    raise
  rescue SocketError => e
    error = "发生错误:  #{e}"
    puts error
    Log.error error
    sleep 60
    retry
  rescue LackMoneyException => e
    puts e
    Log.error error
    puts '等待3分钟...'
    for i in 1..3
      sleep 60
      print '.'
    end
    print '\n'
    retry

  rescue Exception => e
    error = "发生错误:  #{e}"
    puts error
    Log.error error
    #send Message
    retry
  end

  def simplify num
    (((num)*100).to_i)/100.0
  end

  def finish_btcc_trade?
    retry_times ||= 0

    balance = @btcc.account.balance
    cny_balance = balance.cny.to_f
    btc_balance = balance.btc.to_f

    if cny_balance == self.btcc_cny_balance && btc_balance == self.btcc_btc_balance
      return false
    else
      return true
    end

  rescue Exception => e
    error = "获取余额发生错误：#{e}"
    puts error if debug

    if retry_times < retry_limit * 2
      retry_times += 1
      puts "正在重试..." if debug
      retry
    else
      raise
    end
  end

  def finish_bter_trade?
    retry_times ||= 0

    balance = @bter.balance
    cny_balance = balance['CNY']
    btc_balance = balance['BTC']

    if cny_balance == self.bter_cny_balance && btc_balance == self.bter_btc_balance
      return false
    else
      return true
    end

  rescue Exception => e
    error = "获取余额发生错误：#{e}"
    puts error if debug

    if retry_times < retry_limit * 2
      retry_times += 1
      puts "正在重试..." if debug
      retry
    else
      raise
    end
  end
end

#TODO  分情况检测余额
#btcc buy sell错误处理
#

bter = Bter.new '86EB2B7B-848A-423E-8E63-5FAC295193AB', '08b78689ef43f6f23deb6d2125d841e7c3cb799652137cd45501c095c2d2bbb1'

ChinaShop.configure do |config|
  config.key = '57e46e51-8747-4159-9b1d-357e119767e1'
  config.secret = 'af46fbd8-683c-4fec-9194-c1b7b246fb85'
end


t = Trade.new bter, ChinaShop
t.price_spread = 100
#t.debug = true
puts '开始运行...'
t.start
