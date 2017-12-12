# Jekyll::Tweetsert

*Tweetsert* is a plugin for Jekyll that pulls recent tweets from one or more Twitter handles, then inserts them (dated appropriately) as regular posts on your site. You can specify which tweets to include or exclude based on patterns or words, import retweets and replies, and tweak the theme and link colors of the embedded tweet.

To organize your tweet-posts, Tweetsert can automatically assign a category and/or tag. You may also choose to automatically import Twitter hashtags.

### Why do this?

1. You want your blog readers to also see your recent tweets when they visit;
1. You may want to pull in tweets from friends, family, co-workers, etc. into your blog;
1. You want to create a blog composed only of tweets from a group of people;
1. Just for fun!

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jekyll-tweetsert'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jekyll-tweetsert

In compliance with the spirit of Twitter's API usage guidelines, you will need an access token. Get it here:

> **[tweetsert.hook.io](http://tweetsert.hook.io)**

You will be directed to Twitter's OAuth system. Once you grant permission (read-only), you will be presented with a token that you then place into your `_config.yml`. If you don't want to do that, you may use the environment variable **`JTP_ACCESS_TOKEN`** instead.

```
$ export JTP_ACCESS_TOKEN="..."
$ jekyll serve
```

## Usage

The minimum configuration to run *Tweetsert* is the following:

```yaml
tweetsert:
  enabled: true
  timeline:
    handle: 'ibrado'
    access_token: "12345678-aBcDeFgHiJkLmNoPqRsTuVwXyZajni01234567890"
```

Here is a sample `_config.yml` section, with comments:

```yaml
tweetsert:
  enabled: true
  layout: "tweet" # Template in _layouts to use; default "page"

  # Show additional messages for debugging
  #debug: true

  # Prefix, number of words, and suffix of the generated titles
  title:
    #prefix: "[Tweet] "
    words:  9
    suffix: " ..."

  # Some post/page properties you may want to set automatically
  #properties:
  #  is_tweet: true
  #  tweet_html: $    # the embedded tweet
  #  share: false
  #  comments: true

  # The timeline(s) you import, and which tweets you want/don't want
  timeline:
    # Your handle; you may also just use 'handles' below
    handle: 'ibrado'

    # Other handles you want to include
    # If you get an 404 Not Found, you may have misspelled a handle
    #handles:
    #  - 'somehandle'
    #  - 'anotherhandle'

    # The token you got via tweetsert.hook.io
    # You may also use the JTP_ACCESS_TOKEN environment variable instead
    access_token: "12345678-aBcDeFgHiJkLmNoPqRsTuVwXyZajni01234567890"

    # Timeline entries to retrieve. Limited by Twitter to 200; default 100
    # Note that this includes deleted tweets, so it's not exact
    limit: 100

    # Include tweets starting with @handle; default: false
    #replies: true

    # Include retweets (RT); default false
    #retweets: true

    # If both include and exclude are configured below,
    # only tweets pulled in by "include" will be further filtered by "exclude"

    # Only include tweets that have these words/handles/hashtags/URLs
    #  (case insensitive regex)
    #include:
      #- '#blog'
      #- '(^|[^@\w])@(\w{1,15})\b' # Must mention @someone
      #- 'important'
      #- '@handle'

    # Exclude tweets that have these words/handles/hashtags/URLs
    #   (case insensitive regex)
    exclude:
      - 'https://example.org/\d+/' # Your own blog posts
      #- 'ignore'
      #- '#somehash'
      #- '@handle'

    # Do not include tweets newer than your latest post; default true
    #no_newer: false

    # Do not include tweets older than your first post; default true
    #no_older: false

  embed:
    # Set to false if you don't want the excerpt to be set; default true
    #excerpts: false

    # Set to dark if you want a dark background/light text; default: light
    #theme: "dark"

    # Base color of the links, default: set by Twitter
    #link_color: "#80FF80"

    # Include Twitter's oEmbed API script every time; default: false
    # Set to true if you manually include it in e.g. the header
    #omit_script: true

  category:
    default: "tweets"                  # Automatically set to this category
    dir: ""                            # Folder that contains your categories
    #dir: "categories"                 # Default

    layout: "cat_index.html"           # What layout to use, inside _layouts
    #layout: "category_index.html"     # Default

    #title:
    #  prefix: "Posts in the &laquo;"  # Prefix of the generated title
    #  suffix: "&raquo; category"      # Suffix of the generated title

  tags:
    #default: "tweet"                  # Tag all tweets automatically with this
    dir: "tag"                         # Location of the generated tag indices
    layout: "tag_index.html"           #  As above, for tags
    #title:
    #  prefix: "Posts tagged &ldquo;"
    #  suffix: "&rdquo;"

    #hashtags: true                     # Import #hashtags as site tags

    # Hashtags you don't want to import
    ignore:
      - blahblah

    # Automatic tagging based on content, tag: <string or array>
    #auto:
    #  keepkey: "@bitcoinkeepkey"
    #  ethereum: "ethereum"
    #  pets:
    #    - buzzfeedanimals
    #    - Duchess
    #    - Princess
    #    - Athos

```

Here's another one, cleaned-up:

```yaml
tweetsert:
  enabled: true
  layout: "post"
  debug: false

  title:
    prefix: "[Tweet] "
    words:  9
    suffix: " ..."

  properties:
    is_tweet: true
    tweet_html: $
    share: false
    comments: true

  timeline:
    handle: 'ibrado'

    handles:
      - 'somehandle'
      - 'anotherhandle'

    access_token: "12345678-aBcDeFgHiJkLmNoPqRsTuVwXyZajni01234567890"
    limit: 100

    replies: false
    retweets: true

    #include:
    #  - '#blogimport'

    exclude:
      - 'https://example.org/\d+/'

    no_newer: true
    no_older: false

  embed:
    excerpts: true
    theme: "dark"
    link_color: "#80FF80"
    omit_script: false

  category:
    default: "tweets"
    dir: ""

    layout: "category_index"
    title:
      prefix: "Posts in the &laquo;"
      suffix: "&raquo; category"

  tags:
    default: "tweet"
    dir: "tag"

    layout: "tag_index"
    title:
      prefix: "Posts tagged &ldquo;"
      suffix: "&rdquo;"

    hashtags: true
    ignore:
      - "blahblah"

    auto:
      keepkey: "@bitcoinkeepkey"
      cryptocurrency: [ "bitcoin", "ethereum", "litecoin" ]
      ethereum:
        - "ethereum"
        - "@ethereumproject"


```

## Cache

*Tweetsert* caches Twitter's oEmbed results in a hidden folder, `.tweetsert-cache`. You may delete this if you encounter problems that you think might be related to the cache.

## Further configuration

You may want to edit your `home` layout to make the imported tweets look different from the regular ones, for instance,

```
{% for post in site.posts %}
  {% if post.tags contains "tweet" %}
	<br/>
  {% else %}
    <!-- normally post header -->
  {% endif %}
{% endfor %}
```

See the [author's blog](https://ibrado.org) for a demo.

## Contributing

1. Fork this project: [https://github.com/ibrado/jekyll-tweetsert/fork](https://github.com/ibrado/jekyll-tweetsert/fork)
1. Clone it (`git clone git://github.com/your_user_name/jekyll-tweetsert.git`)
1. `cd jekyll-tweetsert`
1. Create a new branch (e.g. `git checkout -b my-bug-fix`)
1. Make your changes
1. Commit your changes (`git commit -m "Bug fix"`)
1. Build it (`gem build jekyll-tweetsert.gemspec`)
1. Install and test it (`gem install ./jekyll-tweetsert-*.gem`)
1. Repeat from step 3 as necessary
1. Push the branch (`git push -u origin my-bug-fix`)
1. Create a Pull Request, making sure to select the proper branch, e.g. `my-bug-fix` (via https://github.com/*your_user_name*/jekyll-tweetsert)

Bug reports and pull requests are welcome on GitHub at [https://github.com/ibrado/jekyll-tweetsert](https://github.com/ibrado/jekyll-tweetsert). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct
Everyone interacting in the Jekyll::Tweetsert project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/jekyll-tweetsert/blob/master/CODE_OF_CONDUCT.md).
