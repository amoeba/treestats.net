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

            # Deal with whether we're searching players or allegiances.
            # Use key existence (not value truthiness) so that an empty or
            # nil value (e.g. ?character or ?character=) still triggers the
            # character search path.
            if params.include?('character')
              character_query = params['character'] || ""
              criteria.merge!(SearchHelper.process_search(character_query))
              @records = Character.asc(:name).where(criteria).limit(page_size).offset(offset)
            elsif params.include?('allegiance')
              allegiance_query = params['allegiance']
              if allegiance_query && allegiance_query.length >= 0
                criteria[:name] = /#{Regexp.escape(allegiance_query)}/i
              end

              @records = Allegiance.where(criteria).asc(:server).limit(page_size)
            else
              # Default to character search when no search param is present
              @records = Character.asc(:name).where(criteria).limit(page_size).offset(offset)
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
