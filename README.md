# `asger` #

`asger` is a tool designed to field notifications from Amazon EC2 auto-scaling groups via a SNS topic subscribed to an SQS queue. (Which probably sounds alarmingly specific, but it's the most common way to do this!) Once a notification is fielded, the user can define Tasks that then perform actions on instance creation ("up" functions) and termination ("down" functions).

### Important Notes ###
- When multiple tasks are running in a single `asger` instance, they will be run in order on instance creation and _in reverse order_ on instance termination.

## Contributors ##
`asger` was built primarily at [Leaf](http://leaf.me) by [Ed Ropple](mailto:ed+asger@edropple.com) ([twitter](https://twitter.com/edropple)).

## Standalone ##

`asger` is designed primarily to be run as a daemon, accepting "tasks" in the form of Ruby files. Tasks are [fairly simple](https://github.com/eropple/asger/blob/master/samples/echo.rb); more documentation will be forthcoming.

Sample usage:

```bash
./bin/asger --queue-url 'https://sqs.us-east-1.amazonaws.com/ACCOUNT_ID/QUEUE_NAME' --shared-credentials=CREDS --parameter-file /tmp/some_params.yaml --task-file samples/echo.rb
```

## Embedded ##

Add this line to your application's Gemfile:

```ruby
gem 'asger'
```

And then execute:

```bash
bundle
```

Or install it yourself as:

```bash
gem install asger
```

Yardocs are available with `yard`, and in a moderate state of completion. Nothing in `asger` is particularly complicated, though, so I recommend just taking a look at the source.

## Contributing ##

1. Fork it ( https://github.com/[my-github-username]/asger/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
