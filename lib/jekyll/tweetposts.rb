require "jekyll/tweetposts/version"
require 'net/http'
require "uri"
require "json"
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
      include Comparable
      def initialize(path, site, docs, date, id, content)
        @path = path
        @site = site
        @collection = docs

        self.data['date'] = date
        self.data['title'] = "Tweet #{id}"
        self.content = content
      end
    end

    class TweetPage < Jekyll::Page
      def initialize(site, base, dir, name, date, id, content)
        @site = site
        @base = base
        @dir = dir
        @name = name

        self.process(@name)
        # The layout for the actual file
        self.read_yaml(File.join(base, '_layouts'), 'tweet.html')

        self.data['date'] = date
        self.data['title'] = "Tweet #{id}"
        #self.data['content'] = content
        self.content = content
        puts "New page at "+self.path
      end
    end

    class Generator < Jekyll::Generator
      def generate(site)
        config = site.config["tweetposts"]
        if config.nil? || !config["enabled"]
          err_msg = "Please add/enable the Tweetposts configuration to your _config.yml"
          Jekyll.logger.warn "Tweetposts:", err_msg
          return
          #raise ArgumentError.new(err_msg)
        end

        APICache.store = Moneta.new(:File, dir: './.tweetposts-cache')

      # find timeframe, i.e. earliest and latest posts

        # Random(?) future date
        oldest = DateTime.new(2974,1,30)
        newest = DateTime.new()

        # posts.each should be changed to posts.docs.each.
        site.posts.docs.each do |post|
          timestamp = post.data["date"].to_datetime
          # All posts have dates or Jekyll will stop
          oldest = [oldest, timestamp].min
          newest = [newest, timestamp].max
          break
        end

        handle = config["handle"]
        Jekyll.logger.info "Tweetposts:", "Retrieving timeline of "+ handle
        params = {
          screen_name: handle,
          count: config["limit"] || 100,
          trim_user: true
        }

        #omit_script = 0;

        if tweets = retrieve('timeline-'+handle, TWITTER_TIMELINE_API, params, {:Authorization => "Bearer " + config["access_token"]}, 60)
          post_count = 0
          tweets.select { |tweet|
            (tweet['timestamp'] = DateTime.parse(tweet["created_at"]).new_offset(DateTime.now.offset)) >= oldest

          }.each do |tweet|
            if site.layouts.key? 'tweet'
              date = tweet['timestamp'].strftime('%Y-%m-%d %H:%M:%S %z')
              category = config['tweets_category'] || 'tweets'
              id = tweet["id"].to_s

              name = "tweet-"+id+".html"

              newdoc = Jekyll::Document.new(File.join(site.source, category, name), { :site => site, :collection => site.posts })

              newdoc.data["title"] = "tweet "+id
              newdoc.data["date"] = tweet["timestamp"]
              newdoc.data["layout"] = "page"

              params = {
                url: "https://twitter.com/"+handle+"/status/"+ id #,
                #omit_script: omit_script
              }

              if oembed = retrieve('oembed-'+id, TWITTER_OEMBED_API, params, {}, 864000);
                newdoc.content = oembed["html"]
                newdoc.data["title"] = oembed["html"].gsub(/<[^>]+>/, '').split(/s+/).slice(0 .. 8).join(" ");
                newdoc.data["excerpt"] = Jekyll::Excerpt.new(newdoc);
                site.posts.docs << newdoc
                #omit_script = 1
                post_count += 1
              end
            end
          end

          Jekyll.logger.info "Tweetposts:", "Generated "+post_count.to_s+" tweetposts"
        end

      end

      def retrieve(type, url, params, headers, cache)
        uri = URI(url)
        APICache.get(type, { :cache => cache, :fail => DEFAULT_HTTP_ERROR_JSON }) do
          qs = params.map{ |a| a.join('=') }.join('&')
          qs = '?'+qs unless qs.empty?

          Net::HTTP.start(uri.host, use_ssl: true) do |http|
            req = Net::HTTP::Get.new(uri.path + qs)

            DEFAULT_REQUEST_HEADERS.merge(headers).each { |k, v| req[k] = v }

            response = http.request(req)
            case response
            when Net::HTTPSuccess
              JSON.parse(response.body)
            else
              raise APICache::InvalidResponse
            end
          end
        end
      end
    end
  end
end
