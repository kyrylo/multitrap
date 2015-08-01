require 'multitrap'

require 'bundler'
require 'pry'
require 'rspec/wait'

RSpec.configure do |c|
  c.order = 'random'
  c.color = true
  c.wait_timeout = 5
end
