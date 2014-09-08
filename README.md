# Multitrap

The idea is to be able to attach multiple callbacks for `Signal.trap`.

```ruby
require 'multitrap'

trap('INT') do
  puts 111
end

trap('INT') do
  puts 222
end

Process.kill('INT', $$)

# Outputs:
# 111
# 222
```

Currently, the library doesn't achieve the goal. I want to make the gem
unobtrusive: the user installs it and it "just works". However, it's not
possible due to a limitation of MRI. If you earlier have defined traps and then
require Multitrap, it discards your callback previous older callback.

```ruby
trap('INT') do
  puts 111
end

require 'multitrap'

trap('INT') do
  puts 222
end

trap('INT') do
  puts 333
end

Process.kill('INT', $$)

# Outputs:
# 222
# 333
```

However, it's possible to bypass this limitation. Just redefine your trap
when Multitrap is loaded.

```ruby
trap_proc = trap('INT') do
  puts 111
end

require 'multitrap'

trap('INT', trap_proc)

trap('INT') do
  puts 222
end

Process.kill('INT', $$)

# Outputs:
# 111
# 222
# 333
```

## Installation

Add this line to your application's Gemfile:

    gem 'multitrap'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install multitrap

## Limitations

### Rubies

* MRI 2.1

### Known bugs

* recursive traps are broken (fixable)
* overwrites traps defined before the loading of the library (not fixable,
  requires patching MRI)
