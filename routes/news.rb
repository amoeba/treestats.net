module Sinatra
  module TreeStats
    module Routing
      module News
        def self.registered(app)
          app.get '/news/?' do
            @page = news_page
            @posts = NewsPost.published.skip((@page - 1) * NewsHelper::NEWS_PAGE_SIZE)
              .limit(NewsHelper::NEWS_PAGE_SIZE + 1).to_a
            @has_next = @posts.length > NewsHelper::NEWS_PAGE_SIZE
            @posts = @posts.first(NewsHelper::NEWS_PAGE_SIZE)
            haml :news
          end

          app.get '/news/:slug/?' do
            @post = NewsPost.published.where(slug: params['slug']).first
            halt 404 unless @post
            haml :news_post
          end

          app.get '/admin/news/?' do
            require_admin!
            @page = news_page
            @posts = NewsPost.order_by(updated_at: :desc, _id: :desc)
              .skip((@page - 1) * NewsHelper::NEWS_PAGE_SIZE).limit(NewsHelper::NEWS_PAGE_SIZE + 1).to_a
            @has_next = @posts.length > NewsHelper::NEWS_PAGE_SIZE
            @posts = @posts.first(NewsHelper::NEWS_PAGE_SIZE)
            haml :admin_news, layout: :admin_news_layout
          end

          app.get '/admin/news/new/?' do
            require_admin!
            @post = NewsPost.new
            prepare_news_form
            haml :admin_news_form, layout: :admin_news_layout
          end

          app.get '/admin/news/:id/edit/?' do
            require_admin!
            @post = find_news_post!
            prepare_news_form
            haml :admin_news_form, layout: :admin_news_layout
          end

          app.post '/admin/news/?' do
            require_admin!
            verify_csrf!
            @post = NewsPost.new
            save_news_post
          end

          # Preview returns the editor with its unsaved fields intact. It never
          # persists a document, publishes content, or accepts arbitrary HTML.
          ['/admin/news/preview/?', '/admin/news/:id/preview/?'].each do |path|
            app.post path do
              require_admin!
              verify_csrf!
              @post = params['id'] ? find_news_post! : NewsPost.new
              apply_news_fields
              @preview_html = NewsMarkdown.render(@post.body)
              haml :admin_news_form, layout: :admin_news_layout
            end
          end

          app.post '/admin/news/:id/?' do
            require_admin!
            verify_csrf!
            @post = find_news_post!
            save_news_post
          end
        end
      end
    end
  end
end
