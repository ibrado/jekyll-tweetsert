require "jekyll/tweetposts/version"
require 'net/http'
require "uri"
require "json"
require "digest"
require "api_cache"
require "moneta"

module Jekyll
  module Tweetposts
    TWITTER_TIMELINE_API = "https://api.twitter.com/1.1/statuses/user_timeline.json".freeze
    TWITTER_OEMBED_API = "https://publish.twitter.com/oembed".freeze
    DEFAULT_REQUEST_HEADERS = { "User-Agent": "Jekyll TweetPosts Plugin v#{VERSION}" }.freeze
    DEFAULT_HTTP_ERROR_JSON = { "html": "Error retrieving URL" }.freeze

    class TweetDoc < Jekyll::Document
      #attr_accessor :content
      #include Comparable
      def initialize(path, site, docs, date, id, content)
        @path = path
        @site = site
        @collection = docs

        self.data['date'] = date
        self.data['title'] = "Tweet #{id}"
        self.content = content
      end
    end

    class TweetCategoryIndex < Jekyll::Page
      def initialize(site, base, dir, category)
        @site = site
        @base = base
        @dir = dir
        @name = 'index.html'

        self.process(@name)

        cat_config = site.config['tweetposts']['category'] || {}

        layout = cat_config["layout"] || "category_index.html"
        self.read_yaml(File.join(base, '_layouts'), layout)

        self.data['category'] = category

        prefix = cat_config.has_key?("title") ? cat_config['title']['prefix'] : ""
        suffix = cat_config.has_key?("title") ? cat_config['title']['suffix'] : ""

        self.data['title'] = prefix + category + suffix
      end
    end


    class TweetTagIndex < Jekyll::Page
      def initialize(site, base, dir, tag)
        @site = site
        @base = base
        @dir = dir
        @name = 'index.html'

        self.process(@name)

        tag_config = site.config['tweetposts']['tags']

        layout = tag_config["layout"] || "tag_index.html"
        self.read_yaml(File.join(base, '_layouts'), layout)

        self.data['tag'] = tag

        prefix = tag_config.has_key?("title") ? tag_config['title']['prefix'] : ""
        suffix = tag_config.has_key?("title") ? tag_config['title']['suffix'] : ""

        self.data['title'] = prefix + tag + suffix
      end
    end


    class Generator < Jekyll::Generator

      def generate(site)
        config = site.config["tweetposts"]

        if config.nil? || !config["enabled"]
          return
        end

        if !config.has_key?("timeline") || !config.has_key?("embed")
          Jekyll.logger.error "Tweetposts:", "Timeline and/or embed cofiguration not found"
          return
        end

        timeline = config["timeline"]
        embed = config["embed"]

        APICache.store = Moneta.new(:File, dir: './.tweetposts-cache')

        bracket = timeline['stop_at_oldest_post'] || timeline['stop_at_oldest_post'].nil?

        if bracket
          # find timeframe, i.e. earliest and latest posts
          # Random(?) future date
          oldest = DateTime.new(2974,1,30)
          #newest = DateTime.new()

          # posts.each should be changed to posts.docs.each.
          site.posts.docs.each do |post|
            timestamp = post.data["date"].to_datetime
            # All posts have dates or Jekyll will stop
            oldest = [oldest, timestamp].min
            #newest = [newest, timestamp].max
          end
        else
          oldest = DateTime.new()
        end

        handles = []
        handles << timeline["handle"] if timeline["handle"]
        (handles << timeline["handles"]).flatten! if timeline["handles"]

        exclude_replies = timeline['replies'] ? '0' : '1'
        include_retweets = timeline['retweets'] ? '1' : '0'

        cat_config = config["category"] || {}
        category = cat_config['default'] || ""

        tags_config = config["tags"] || {}
        default_tag = tags_config["default"]

        options = {
          oldest: oldest,
          limit: timeline["limit"] || 100,
          category: category,
          dir: tags_config["dir"],
          layout: (site.layouts.key? config["layout"] || 'tweet'),
          exclude_replies: exclude_replies,
          include_retweets: include_retweets,
          hashtags: tags_config["hashtags"],
          default_tag: default_tag,
          exclusions: timeline['exclude'].reject { |w| w.nil? },
          access_token: get_access_token(timeline["access_token"]),
          embed: embed
        }

        handles.each_with_index do |handle, i|
          counts = generate_posts(site, handle, options)
          msg = handle+": Generated "+counts[:posts].to_s+" tweetpost(s), "+counts[:tags].to_s+" tag(s)"
          if category
            make_cat_index(site, config["category"]["dir"] || "categories", category)
            msg << ", 1 category" if i.zero?
          end
          Jekyll.logger.info "Tweetposts:", msg
        end

      end

      private

      def md5
        return @md5 ||= Digest::MD5::new
      end

      def make_index(site, index)
        index.render(site.layouts, site.site_payload)
        index.write(site.dest)
        site.pages << index
      end

      def make_tag_index(site, dir, tag)
        index = TweetTagIndex.new(site, site.source, File.join(dir, tag), tag)
        make_index(site, index)
      end

      def make_cat_index(site, dir, category)
        index = TweetCategoryIndex.new(site, site.source, File.join(dir, category), category)
        make_index(site, index)
      end

      def retrieve(type, url, params, headers, cache)
        qs = params.map{ |a| a.join('=') }.join('&')
        qs = '?'+qs unless qs.empty?

        md5.reset
        md5 << type+qs

        unique_type = type + "-" + md5.hexdigest

        APICache.get(unique_type, { :cache => cache, :fail => DEFAULT_HTTP_ERROR_JSON }) do
          uri = URI(url)

          #puts unique_type+" Requesting "+uri.path + qs
          Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https' ) do |http|
            req = Net::HTTP::Get.new(uri.path + qs)

            DEFAULT_REQUEST_HEADERS.merge(headers).each { |k, v| req[k] = v }

            response = http.request(req)
            case response
            when Net::HTTPSuccess
              JSON.parse(response.body)
            else
              Jekyll.logger.warn "Tweetposts:", "Got invalid response!"
              puts response.inspect
              raise APICache::InvalidResponse
            end
          end
        end
      end

      def get_access_token(site_token)
        if access = retrieve('access-token', 'https://tweetposts--ibrado.netlify.com/token/jekyll-tweetposts.json', {}, {}, 86400)
          if site_token.nil? || site_token == access["token"]
            Jekyll.logger.warn "Tweetposts:", "Warning: Using default access token"
            Jekyll.logger.warn "Tweetposts:", "  See README.md to setup your own"
          end
          site_token || access["token"]
        else
          Jekyll.logger.error "Tweetposts:", "Default access token not available" if site_token.nil?
          site_token || "no-token-available"
        end
      end

      def generate_posts(site, handle, o)
        params = {
          screen_name: handle,
          count: o[:limit],
          exclude_replies: o[:exclude_replies],
          include_rts: o[:include_retweets],
          tweet_mode: "extended",
          trim_user: 1
        }

        #puts "Using access_token="+access_token

        post_count = 0
        tag_count = 0

        if tweets = retrieve('timeline', TWITTER_TIMELINE_API, params, {:Authorization => "Bearer " + o[:access_token]}, 5)
          seen_tags = {}

          tweets.select { |tweet|
            tweet['timestamp'] = DateTime.parse(tweet["created_at"]).new_offset(DateTime.now.offset)

            excluded = tweet["timestamp"] < o[:oldest]

            if !excluded && o[:exclusions]
              urls = tweet["entities"]["urls"].map { |url| url["expanded_url"] }.join(" ")

              excluded ||= o[:exclusions].any? { |w| tweet["full_text"] =~ /([\b#\@]?)#{w}\b/i } ||
                o[:exclusions].any? { |w| urls =~ /\b#{w}/i }

            end

            !excluded

          }.each do |tweet|

            if o[:layout]
              date = tweet['timestamp'].strftime('%Y-%m-%d %H:%M:%S %z')
              id = tweet["id"].to_s

              name = "tweet-"+id+".html"

              tweetpost = Jekyll::Document.new(File.join(site.source, o[:category], name), { :site => site, :collection => site.posts })

              tweetpost.data["title"] = "tweet "+id
              tweetpost.data["date"] = tweet["timestamp"]
              tweetpost.data["layout"] = "page"

              params = {
                url: "https://twitter.com/"+handle+"/status/"+ id,
                theme: o[:embed]['theme'] || "light",
                link_color: o[:embed]["link_color"],
                omit_script: o[:embed]["omit_script"]
              }

              if oembed = retrieve('oembed', TWITTER_OEMBED_API, params, {}, 864000)
                tweetpost.content = '<div class="jekyll-tweetposts">' + oembed["html"] + '</div>'

                tweetpost.data["title"] = tweet["full_text"].split(/\s+/).slice(0 .. 8).join(" ") + ' ...'
                tweetpost.data["excerpt"] = Jekyll::Excerpt.new(tweetpost)

                tweet_tags = []
                tweet_tags << o[:default_tag] if o[:default_tag] && !o[:default_tag].empty?

                if o[:hashtags]
                  tweet_tags << tweet["full_text"].downcase.gsub(/&\S[^;]+;/, '').scan(/[^&]*?#([A-Z0-9_]+)/i).flatten || []
                end

                tweetpost.data["tags"] = tweet_tags.flatten
                tweetpost.data["category"] = o[:category]

                site.posts.docs << tweetpost

                tweetpost.data["tags"].each do |tag|
                  make_tag_index(site, o[:dir] || "tag", tag)
                  if !seen_tags.has_key?(tag)
                    tag_count += 1
                    seen_tags[o[:default_tag]] = 1
                  end
                end

                #omit_script = 1
                post_count += 1
              end # oembed

            end # layout
          end # each
        end # if tweets

        return {
          :posts => post_count,
          :tags => tag_count
        }

      end # def

    end # class
  end # module
end #module
