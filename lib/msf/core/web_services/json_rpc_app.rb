require 'securerandom'
require 'sinatra/base'
require 'swagger/blocks'
require 'warden'
require 'msf/core/rpc'
require 'msf/core/web_services/authentication'
require 'msf/core/web_services/framework_extension'
require 'msf/core/web_services/servlet_helper'
require 'msf/core/web_services/servlet/auth_servlet'
require 'msf/core/web_services/servlet/json_rpc_servlet'

module Msf::WebServices
  class JsonRpcApp < Sinatra::Base
    helpers ServletHelper
    helpers Msf::RPC::JSON::DispatcherHelper

    # Extension registration
    register FrameworkExtension

    # Servlet registration
    register JsonRpcServlet

    configure do
      set :logging, Logger::DEBUG
      set :dispatchers, {}

      set :sessions, {key: 'msf-ws.session', expire_after: 300}
      set :session_secret, ENV.fetch('MSF_WS_SESSION_SECRET', SecureRandom.hex(16))
      set :api_token_file, ENV.fetch('MSF_API_TOKEN_FILE', nil)
      unless :api_token_file.nil?
        file = File.read(settings.api_token_file)
        data = JSON.parse(file)
        set :token_from_file, data[:token]
      end

    end

    def db_ready(db)
      begin
        db.check
      rescue
        false
      end
    end

    before do
      # store DBManager in request environment so that it is available to Warden
      db = get_db
      if db_ready(db)
        request.env['msf.db_manager'] = db
        @@auth_initialized ||= db.users({}).count > 0
      else
        if !settings.token_from_file.nil?
          @@auth_initialized = true
        else
          @@auth_initialized = false
        end
      end

      # store flag indicating whether authentication is initialized in the request environment
      request.env['msf.auth_initialized'] = @@auth_initialized
    end

    use Warden::Manager do |config|
      # failed authentication is handled by this application
      config.failure_app = self
      # don't intercept 401 responses since the app will provide custom failure messages
      config.intercept_401 = false
      config.default_scope = :api

      config.scope_defaults :user,
                            # whether to persist the result in the session or not
                            store: true,
                            # list of strategies to use
                            strategies: [:password],
                            # action (route) of the failure application
                            action: "#{AuthServlet.api_unauthenticated_path}/user"

      config.scope_defaults :api,
                            # whether to persist the result in the session or not
                            store: false,
                            # list of strategies to use
                            strategies: [:api_token],
                            # action (route) of the failure application
                            action: AuthServlet.api_unauthenticated_path

      config.scope_defaults :admin_api,
                            # whether to persist the result in the session or not
                            store: false,
                            # list of strategies to use
                            strategies: [:admin_api_token],
                            # action (route) of the failure application
                            action: AuthServlet.api_unauthenticated_path
    end

  end
end
