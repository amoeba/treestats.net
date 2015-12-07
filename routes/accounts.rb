module Sinatra
  module TreeStats
    module Routing
      module Accounts
        def self.registered(app)
          app.post '/account/create/?' do
            body = request.body.read
            fields = JSON.parse(body)

            # Handle case where (somehow) not all fields are sent
            if(!fields.has_key?("name") &&
              !fields.has_key?("password"))
              return "Not all fields were received. Account not created."
            end

            # Validate fields:
            #  Name already exists

            if(Account.where(name: fields["name"]).exists?)
              return "Account with this name already exists."
            end

            # Validate:
            #  Nam or password is wrong format
            #    Name: [a-zA-Z'] {length > 0}
            #    Password: {length > 0}

            if(/^[a-zA-Z'\- ]+$/.match(fields["name"]) == nil)
              return "Account name must only contain a-z, A-Z, -, and '."
            end

            if(fields["password"].length < 1)
              return "Password must be at least one character in length."
            end

            c = Account.create(fields)

            return "Account successfully created."
          end

          app.post '/account/login/?' do
            body = request.body.read
            fields = JSON.parse(body)

            if(!fields.has_key?("name") || !fields.has_key?("password"))
              return "Error sending login information to server: Name and password were not specified."
            end

            if(Account.where(name: fields["name"], password: fields["password"]).exists?)
              return "You are now logged in."
            else
              return "Login failed. Name/password not found."
            end
          end

          app.get '/account/:account_name/?' do
            @characters = Character.where(account_name: params[:account_name]).all

            haml :account
          end
        end
      end
    end
  end
end
