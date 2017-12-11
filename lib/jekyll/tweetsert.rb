require "jekyll/tweetsert/version"
require 'net/http'
require "uri"
require "cgi"
require "json"
require "digest"
require "api_cache"
require "moneta"

module Jekyll
  module Tweetsert
    REQUEST_SIGNER = "https://hook.io/tweetsert/sign".freeze

    TWITTER_OEMBED_API = "https://publish.twitter.com/oembed".freeze

    DEFAULT_REQUEST_HEADERS = { "User-Agent": "Jekyll Tweetsert Plugin/#{VERSION}" }.freeze
    DEFAULT_HTTP_ERROR_JSON = { "html": "Error retrieving URL" }.freeze

=begin
    TODO: Move stuff here
    class TweetPost < Jekyll::Document
      def initialize(path, site, docs, date, id, content)
        @path = path
        @site = site
        @collection = docs

        self.data['date'] = date
        self.data['title'] = "Tweet #{id}"
        self.content = content
      end
    end
=end

    class TweetCategoryIndex < Jekyll::Page
      def initialize(site, base, dir, category)
        @site = site
        @base = base
        @dir = dir
        @name = 'index.html'

        self.process(@name)

        cat_config = site.config['tweetsert']['category'] || {}

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

        tag_config = site.config['tweetsert']['tags']

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
        config = site.config["tweetsert"]

        if config.nil? || !config["enabled"]
          return
        end

        if !config.has_key?("timeline")
          Jekyll.logger.error "Tweetsert:", "Timeline configuration not found"
          return
        end

        timeline = config["timeline"]
        if !timeline.has_key?("access_token") && !ENV['JTP_ACCESS_TOKEN']
          Jekyll.logger.error "Tweetsert:", "Cannot retrieve timelines without access_token"
          Jekyll.logger.error "Tweetsert:", "  Go to http://tweetsert.hook.io/ to get one"
          return
        end

        @access_token = config["timeline"]["access_token"] || ENV['JTP_ACCESS_TOKEN']

        APICache.store = Moneta.new(:File, dir: './.tweetsert-cache')

        no_newer = timeline['no_newer'] || timeline['no_newer'].nil?
        no_older = timeline['no_older'] || timeline['no_older'].nil?

        if no_newer || no_older
          # Find timeframe, i.e. earliest and latest posts

          # Random(?) future date
          oldest = DateTime.new(2974,1,30)
          newest = DateTime.new()

          # "posts.each should be changed to posts.docs.each"
          # TODO? Support older Jekyll versions
          site.posts.docs.each do |post|
            timestamp = post.data["date"].to_datetime
            # All posts have dates or Jekyll will stop
            oldest = [oldest, timestamp].min
            newest = [newest, timestamp].max
          end
        end

        oldest = DateTime.new() if !no_older || site.posts.docs.length.zero?
        newest = DateTime.now() if !no_newer || site.posts.docs.length.zero?

        handles = []
        handles << timeline["handle"] if timeline["handle"]
        (handles << timeline["handles"]).flatten! if timeline["handles"]

        cat_config = config["category"] || {}
        category = cat_config['default'] || ""

        tags_config = config["tags"] || {}

        includes = timeline["include"].reject { |w| w.nil? } if timeline["include"]
        excludes = timeline["exclude"].reject { |w| w.nil? } if timeline["exclude"]

        options = {
          oldest: oldest,
          newest: newest,
          limit: timeline["limit"] || 100,
          category: category,
          dir: tags_config["dir"],
          layout: config["layout"] || 'post',
          replies: timeline["replies"] ? '1' : '0',
          retweets: timeline["retweets"] ? '1' : '0',
          hashtags: tags_config["hashtags"],
          default_tag: tags_config["default"],
          inclusions: includes,
          exclusions: excludes,
          embed: config["embed"] || {},
          properties: config["properties"] || {}
        }

        begin
          cat_count = 0
          handles.each do |handle|
            counts = generate_posts(site, handle, options)
            msg = handle+": Generated "+counts[:posts].to_s+" post(s), "+counts[:tags].to_s+" tag(s)"
            if !category.empty?
              make_cat_index(site, cat_config["dir"] || "categories", category)
              msg += ", 1 category" if !counts[:posts].zero? && cat_count.zero?
              cat_count = 1
            end
            msg += "; excluded "+counts[:excluded].to_s+" tweet(s)"
            Jekyll.logger.info "Tweetsert:", msg
          end
        rescue Exception => e
          ln = e.backtrace[0].split(':')[1]
          Jekyll.logger.error "Tweetsert:", e.message + " at line " + ln
          #puts e.backtrace
          return
        end

      end

      private
      def md5
        return @md5 ||= Digest::MD5::new
      end

      private
      def make_index(site, index)
        index.render(site.layouts, site.site_payload)
        index.write(site.dest)
        site.pages << index
      end

      private
      def make_tag_index(site, dir, tag)
        index = TweetTagIndex.new(site, site.source, File.join(dir, tag), tag)
        make_index(site, index)
      end

      private
      def make_cat_index(site, dir, category)
        index = TweetCategoryIndex.new(site, site.source, File.join(dir, category), category)
        make_index(site, index)
      end

      private
      def retrieve(type, url, params, headers, cache)
        uri = URI(url)

        qs = params.map{ |a| a.join('=') }.join('&')
        qs += (qs ? '' : '&') + uri.query if uri.query
        qs = '?'+qs if qs

        md5.reset
        md5 << type+qs

        unique_type = type + "-" + md5.hexdigest

        APICache.get(unique_type, { :cache => cache, :fail => DEFAULT_HTTP_ERROR_JSON }) do
          Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https' ) do |http|
            req = Net::HTTP::Get.new(uri.path + qs)
            headers.merge!(DEFAULT_REQUEST_HEADERS).each { |k, v| req[k] = v }

            response = http.request(req)

            case response
            when Net::HTTPSuccess
              JSON.parse(response.body)
            when Net::HTTPUnauthorized
              Jekyll.logger.warn "Tweetsert:", "Unauthorized: check handle(s) and token"
            else
              Jekyll.logger.warn "Tweetsert:", "  " + response.inspect
              #raise APICache::InvalidResponse
            end
          end
        end
      end

      private
      def sign_timeline_request(params)
        uri = URI(REQUEST_SIGNER)

        qs = params.map{ |a| a.join('=') }.join('&')
        qs = '?'+qs unless qs.empty?

        Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https') do |http|
          req = Net::HTTP::Get.new(uri.path + qs)
          req['X-JTP-Access-Token'] = @access_token

          response = http.request(req)

          case response
          when Net::HTTPSuccess
            # contains url and auth
            JSON.parse(response.body)
          else
            Jekyll.logger.warn "Tweetsert:", "  " + response.inspect
            raise APICache::InvalidResponse
          end
        end
      end

      private
      def generate_posts(site, handle, o)
        params = {
          handle: handle,
          limit: o[:limit],
          replies: o[:replies],
          retweets: o[:retweets],
        }

        signed = sign_timeline_request(params)
        if signed.nil?
          Jekyll.logger.error "Tweetsert:", "Cannot retrieve timeline of "+o[:handle]
          return
        end

        post_count = 0
        tag_count = 0
        exclude_count = 0

        if tweets = retrieve('timeline', signed["url"], {}, { "Authorization" => signed["auth"] }, 5)
          seen_tags = {}
          tweets.select { |tweet|
            urls = tweet["entities"]["urls"].map { |url| url["expanded_url"] }.join(" ")

            tweet['timestamp'] = DateTime.parse(tweet["created_at"]).new_offset(DateTime.now.offset)

            excluded = (tweet["timestamp"] > o[:newest]) || (tweet["timestamp"] < o[:oldest])

            if !excluded && o[:inclusions]
              excluded = !(o[:inclusions].any? { |w| tweet["full_text"] =~ /([\b#\@]?)#{w}\b/i } ||
                o[:inclusions].any? { |w| urls =~ /\b#{w}/i })
            end

            if !excluded && o[:exclusions]
              excluded = o[:exclusions].any? { |w| tweet["full_text"] =~ /([\b#\@]?)#{w}\b/i } ||
                o[:exclusions].any? { |w| urls =~ /\b#{w}/i }
            end

            exclude_count += 1 if excluded
            !excluded

          }.each do |tweet|

            id = tweet["id"].to_s

            name = "tweet-"+id+".html"

            # TODO Move stuff over to TweetPost class
            tweetpost = Jekyll::Document.new(File.join(site.source, o[:category], name), { :site => site, :collection => site.posts })

            tweetpost.data["title"] = "tweet "+id
            tweetpost.data["date"] = tweet['timestamp'].to_time
            tweetpost.data["layout"] = o[:layout]

            params = {
              url: "https://twitter.com/"+handle+"/status/"+ id,
              theme: o[:embed]['theme'] || "light",
              link_color: o[:embed]["link_color"],
              omit_script: o[:embed]["omit_script"]
            }

            if oembed = retrieve('oembed', TWITTER_OEMBED_API, params, {}, 864000)
              tweetpost.content = '<div class="jekyll-tweetsert">' + oembed["html"] + '</div>'

              tweetpost.data["title"] = tweet["full_text"].split(/\s+/).slice(0 .. 8).join(" ") + ' ...'
              tweetpost.data["excerpt"] = Jekyll::Excerpt.new(tweetpost)

              tweet_tags = []
              tweet_tags << o[:default_tag] if o[:default_tag] && !o[:default_tag].empty?

              if o[:hashtags]
                tweet_tags << tweet["full_text"].downcase.gsub(/&\S[^;]+;/, '').scan(/[^&]*?#([A-Z0-9_]+)/i).flatten || []
              end

              tweetpost.data["tags"] = tweet_tags.flatten
              tweetpost.data["category"] = o[:category]

              o[:properties].each do |prop, value|
                if !tweetpost.data.key?(prop)
                  if value == '$'
                    tweetpost.data[prop] = oembed['html']
                  else
                    tweetpost.data[prop] = value.to_s
                  end
                end
              end

              site.posts.docs << tweetpost

              tweetpost.data["tags"].each do |tag|
                make_tag_index(site, o[:dir] || "tag", tag)
                if !seen_tags.has_key?(tag)
                  tag_count += 1
                  seen_tags[o[:default_tag]] = 1
                end
              end

              post_count += 1
            end
          end
        end

        return {
          :posts => post_count,
          :tags => tag_count,
          :excluded => exclude_count
        }

      end

    end
  end
end
