module Veri
  class Error < StandardError; end
  class ConfigurationError < Veri::Error; end
  class InvalidArgumentError < Veri::Error; end
  class NotFoundError < Veri::Error; end

  def configure
    yield(Veri::Configuration.instance)
  end
  module_function :configure
end
