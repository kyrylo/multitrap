require 'thread'

module Multitrap
  # The VERSION file must be in the root directory of the library.
  VERSION_FILE = File.expand_path('../../VERSION', __FILE__)

  VERSION = File.exist?(VERSION_FILE) ?
              File.read(VERSION_FILE).chomp : '(could not find VERSION file)'

  def self.jruby?
    RUBY_ENGINE == 'jruby'
  end

  def self.mri?
    RUBY_ENGINE == 'ruby'
  end

  def self.rbx?
    RUBY_ENGINE == 'rbx'
  end
end

require 'multitrap/trap'
require 'multitrap/patched_trap'
require 'multitrap/core_ext'
