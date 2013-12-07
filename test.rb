require 'chinashop'
require 'debugger'

ChinaShop.configure do |config|
    config.key = '035d1452-2ce3-48ea-8676-6971ac7d4dd1'
    config.secret = 'd8b408a9-8cad-4bcd-a928-131303c684a7'
end

debugger
puts ChinaShop.ticker.low
