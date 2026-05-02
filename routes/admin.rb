module Sinatra
  module TreeStats
    module Routing
      module Admin
        def self.registered(app)
          app.get '/admin/login/?' do
            halt 404 if admin?

            @csrf_token = csrf_token
            session[:login_form_rendered_at] = Time.now.to_f

            haml :admin_login, layout: false
          end

          app.post '/admin/login/?' do
            verify_csrf!

            if admin_login_rate_limited?
              halt 404
            end

            if params['website'].to_s != ''
              record_failed_login_attempt!
              halt 404
            end

            rendered_at = session[:login_form_rendered_at].to_f
            if rendered_at <= 0 || (Time.now.to_f - rendered_at) < AdminHelper::LOGIN_MIN_FILL_SECONDS
              record_failed_login_attempt!
              halt 404
            end

            name = params['name'].to_s
            password = params['password'].to_s

            if name.empty? || password.empty?
              record_failed_login_attempt!
              halt 404
            end

            user = AdminUser.where(name: name).first

            if user && user.authenticate(password)
              session.clear
              session[:admin_user_id] = user.id.to_s
              session[:csrf] = SecureRandom.hex(32)
              redirect '/'
            else
              record_failed_login_attempt!
              halt 404
            end
          end

          app.post '/admin/logout/?' do
            verify_csrf!
            session.clear
            redirect '/'
          end

          app.post '/admin/character/:server/:name/archive/?' do |server, name|
            require_admin!
            verify_csrf!

            character = Character.unscoped.where(server: server, name: name).first
            halt 404 unless character

            target = params['archived'] == 'true'
            character.set(archived: target)

            content_type :html
            haml :_admin_widget, layout: false, locals: { character: character.reload }
          end

          # Catch anything else under /admin before the /:server catch-all
          app.get '/admin/?' do
            halt 404
          end

          app.get '/admin/*' do
            halt 404
          end
        end
      end
    end
  end
end
