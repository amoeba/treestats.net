module Sinatra
  module TreeStats
    module AssetHelper
      def stylesheet_path(name)
        name = "#{name}.css" unless name.end_with?('.css')
        build_asset_path(name)
      end

      def javascript_path(name)
        name = "#{name}.js" unless name.end_with?('.js')
        build_asset_path(name)
      end

      def image_path(name)
        build_asset_path(name)
      end

      private

      def build_asset_path(name)
        name = "/#{name}" unless name.start_with?('/')
        fingerprinted = settings.asset_server.manifest[name]
        "/assets#{fingerprinted || name}"
      end
    end
  end
end
