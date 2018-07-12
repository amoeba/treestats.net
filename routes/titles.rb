module Sinatra
  module TreeStats
    module Routing
      module Titles
        def self.registered(app)
          app.get '/titles/?' do
            @titles = TitleHelper::TITLES
            @titles = @titles.select { |i,t| i > 0 }.sort_by { |i,t| t }

            not_found("No titles found.") if @titles.length < 1

            haml :titles
          end

          app.get '/title/:title' do |title_name|            
            title = TitleHelper::TITLES.select { |i,title| title == title_name }

            not_found("Title #{title} not found.") if title.length == 0

            title_id = title.first[0]
            @title_name = title.first[1]
            @characters = Character.where(:titles.in => [title_id],
                                          :archived => false)
                                   .sort(s: 1, n: 1)
                                   .limit(100)

            haml :title
          end
        end
      end
    end
  end
end
