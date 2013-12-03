require 'logger'

class Log
  def self.init
    if !@logger
      @logger = Logger.new 'log.txt'
      @logger.datetime_format = "%Y-%m-%d %H:%M:%S"
    end
  end

  def self.info message
    init
    @logger.info message
  end

  def self.error message
    init
    @logger.error message
  end
end
