require 'uri'

module Sinatra
  module TreeStats
    module Routing
      module Search
        def self.registered(app)
          app.get '/search/?' do
            # Pagination
            page_size = 50
            @page = SearchHelper.get_page(params[:page])
            @prev_page_params = URI.encode_www_form(params.merge({page: @page - 1}))
            @next_page_params = URI.encode_www_form(params.merge({page: @page + 1}))

            offset = (@page - 1) * page_size
            criteria = {}

            # Deal with which server we're searching
            if(params[:server] && params[:server] != "All Servers")
              criteria[:server] = params[:server]
            end

            # Deal with whether we're searching players or allegiances
            if(params && params[:character])
              if(params[:character].length >= 0)
                criteria.merge!(SearchHelper.process_search(params[:character]))
              end

              @records = Character.asc(:name).where(criteria).limit(page_size).offset(offset)
            elsif(params && params[:allegiance])
              if(params[:allegiance].length >= 0)
                criteria[:name] = /#{Regexp.escape(params[:allegiance])}/i
              end

              @records = Allegiance.where(criteria).asc(:server).limit(page_size)
            end

            @count = @records.count
            @npages = (@count / page_size.to_f).ceil

            haml :search
          end
        end
      end
    end
  end
end
