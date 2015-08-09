Multitrap
=========

[![Build Status](https://travis-ci.org/kyrylo/multitrap.svg?branch=master)](https://travis-ci.org/kyrylo/multitrap)

Introduction
------------

By default, all Ruby implementations allow you to attach only one signal handler
per signal (via `Signal.trap` aka `trap`). This is not very useful, if you want
to perform multiple actions. Whenever you define a new signal handler, it sends
shivers down your spine, because you never know if you're overwriting someone
else's handler (usually, the handler of a library you depend on). Well, now you
don't have to worry about that anymore, because Multitrap solved this problem
for you! Define as many handlers as you wish and be sure they will all execute.

Examples
--------

### Basic example

To use Multitrap just `require` it. No additional configuration is
needed. Internally, the library _redefines_ `trap`. The last defined signal
handler executes first.

```ruby
require 'multitrap'

trap(:INT) { puts 111 }
trap(:INT) { puts 222 }
trap(:INT) { puts 333 }

Process.kill(:INT, $$)

# Outputs:
# 333
# 222
# 111
```

### Nested traps

The library aims to be compatible with every Ruby implementation. For example,
JRuby doesn't support nested traps, but Rubinius and CRuby do. Multitrap obeys
this behaviour.

```ruby
require 'multitrap'

a = nil

trap(:INT) do
  a = 1
  trap(:INT) do
    a = 2
  end
end

puts a #=> nil

# On JRuby `a` will always be equal to 1.
Process.kill(:INT, $$)
puts a #=> 1

# CRuby and Rubinius will continue executing nested traps.
Process.kill(:INT, $$)
puts a #=> 2

Process.kill(:INT, $$)
puts a #=> 2
```

### Return value

With Multitrap, the `trap` method returns a hash with callbacks.

```ruby
require 'pp'
require 'multitrap'

trap(:INT) {}
trap(:HUP) {}
3.times do
  trap(:USR1) {}
end
handlers = trap(:USR2) {}

puts handlers
#=> {"INT"=>[#<Proc:0x00556161d34da8@test.rb:4>],
     "HUP"=>[#<Proc:0x00556161d34420@test.rb:5>],
     "USR1"=>
      [#<Proc:0x00556161d36a68@test.rb:7>,
       #<Proc:0x00556161d33750@test.rb:7>,
       #<Proc:0x00556161d33048@test.rb:7>],
     "USR2"=>[#<Proc:0x00556161d32ad0@test.rb:9>]}
```

You can access this hash to modify the handlers at runtime (but be extremely
careful about that). For example, imagine if you write a test for your program's
`:INT` signal handler and use RSpec. RSpec defines its own `:INT` handler and
with the default `trap` you would simply overwrite it. With Multitrap you can
remove the handler from the hash and then append it later.

```ruby
require 'spec_helper'
require 'multitrap'

RSpec.describe MyLibrary do
  it "works" do
    a = nil
    handlers = trap(:INT) { a = 1 }

    # Store the RSpecs handler. Usually, it's the first element in the array.
    rspec_handler = handlers['INT'].shift

    Process.kill(:INT, $$)
    expect(a).to eq(1)

    # Restore the handler.
    handlers['INT'].unshift(rspec_handler)
  end
end
```

Installation
------------

Add this line to your application's Gemfile:

    gem 'multitrap'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install multitrap

Limitations
-----------

### Rubies

* CRuby 1.9.2 >=
* Rubinius 2.5.8 >= (may work on older versions, untested)
* JRuby 9.0.0.0 >= (shouldn't work on older versions)

Roadmap
-------

### Provide consistency

I'm not sure we need this, but it would be possible to remove inconsistencies
with respect to nested traps on all Ruby platforms.

Licence
