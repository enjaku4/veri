class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

class User < ApplicationRecord
  include Veri::Authenticatable
end

class Client < ApplicationRecord; end
