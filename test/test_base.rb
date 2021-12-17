$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

class ReadingTest < Minitest::Test
  self.class.attr_reader :all_items, :config, :err_block, :err_log

  def self.clear_err_log
    @err_log = []
  end

  def config
    self.class.config
  end

  def err_block
    self.class.err_block
  end

  def err_log
    self.class.err_log
  end
end
