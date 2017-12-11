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

**[tweetsert.hook.io](http://tweetsert.hook.io)**

You will be directed to Twitter's OAuth system. Once you allow read-only permission, you will be presented with a token that you then place into your `_config.yml`. If you don't want to do that, you may use the environment variable **`JTP_ACCESS_TOKEN`** instead.

## Usage

Here is a sample `_config.yml` section, with comments:

```ruby
tweetsert:
  enabled: true
  layout: "tweet" # Template in _layouts to use; default "page"

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
      #- '#pebble'
      #- '@handle'

    # Do not include tweets newer than your latest post; default true
    #no_newer: false

    # Do not include tweets older than your first post; default true
    #no_older: false

  embed:
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

    #hashtags: true                     # Import #hashtags as site tags

    dir: "tag"                         # Location of the generated tag indices
    layout: "tag_index.html"           #  As above, for tags
    #title:
    #  prefix: "Posts tagged &ldquo;"
    #  suffix: "&rdquo;"

```

## Further configuration

You may want to edit your `_layouts/home.html` to make the imported tweets look different from the regular ones, for instance,

```
{% for post in site.posts %}
  {% if post.categories contains "tweets" %}
	<br/>
  {% else %}
	<h2>
	    <a href="{{ post.url | relative_url }}" class="medium post-title">
	        {{ post.title | emojify }}
	    </a>
	</h2>
    <!-- etc... -->
  {% endif %}
{% endfor %}
```

See the [author's blog](https://ibrado.org) for a demo.

## Contributing

1. Fork this project, [https://github.com/ibrado/jekyll-tweetsert/fork](https://github.com/ibrado/jekyll-tweetsert/fork)
1. Create a new branch (e.g. `git checkout -b my-bug-fix`)
1. Make your changes
1. Commit your changes (`git commit -m "Bug fix"`)
1. Build it (`gem build jekyll-tweetsert.gemspec`)
1. Install and test it (`gem install ./jekyll-tweetsert-*.gem`)
1. Repeat from step 3 as necessary
1. Push it (`git push -u origin my-bug-fix`)
1. Create a Pull Request, making sure to select the proper branch, e.g. `my-bug-fix` (https://github.com/*your_user_name*/jekyll-tweetsert)

Bug reports and pull requests are welcome on GitHub at [https://github.com/ibrado/jekyll-tweetsert](https://github.com/ibrado/jekyll-tweetsert). This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct
Everyone interacting in the Jekyll::Tweetsert project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/jekyll-tweetsert/blob/master/CODE_OF_CONDUCT.md).
