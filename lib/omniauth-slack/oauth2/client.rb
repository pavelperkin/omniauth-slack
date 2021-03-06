require 'oauth2/client'
require 'oauth2/response'
require 'omniauth'
require 'omniauth-slack/debug'
require 'omniauth-slack/oauth2/access_token'
require 'omniauth-slack/omniauth/auth_hash'

module OmniAuth
  module Slack
    module OAuth2
      class Client < ::OAuth2::Client
        include OmniAuth::Slack::Debug
      
        attr_accessor :logger, :history, :subdomain
        
        def initialize(*args)
          debug{"args: #{args}"}
          super
          self.logger = OmniAuth.logger
          self.history = {}
          #options[:skip_token_validation] && skip_token_validation
        end
                
        # Overrides OAuth2::Client#get_token to pass in the omniauth-slack AccessToken class.
        def get_token(params, access_token_opts = {}, access_token_class = OmniAuth::Slack::OAuth2::AccessToken) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
          rslt = super(params, access_token_opts, access_token_class)
          #debug{"Client #{self} built AccessToken #{rslt.to_yaml}"}
          debug{"Client #{self} built AccessToken #{rslt}"}
          rslt
        end
        
        # Slack's new v2 oauth get-token response does not follow the OAUTH2 spec,
        # if only a user_scope was requested containing data in the team field.
        #
        # This is a temporary hack to make Slack's new v2 get-token response compatible
        # with the Oauth2 gem (which enforces the OAUTH2 spec for get-token response.
        #
        # These have no effect in Oauth2 gem v1.4.4+
        #
        #   def response_contains_token
        #     true
        #   end
        #
        #   def skip_token_validation
        #     debug{"defining :response_contains_token -> true"}
        #     define_singleton_method :response_contains_token do
        #       debug{"returning -> true"}
        #       return true
        #     end
        #   end
        
        # Logs each API request and stores the API result in @history hash.
        # TODO: There should be some kind of option to disable this.
        def request(*args)
          logger.debug "(slack) API request '#{args[0..1]}'."  # in thread '#{Thread.current.object_id}'."  # by Client '#{self}'
          debug{"API request args #{args}"}
          request_output = super(*args)
          uri = args[1].to_s.gsub(/^.*\/([^\/]+)/, '\1') # use single-quote or double-back-slash for replacement.
          history[uri.to_s] = request_output
          #debug{"API response (#{args[0..1]}) #{request_output.class}"}
          debug{"API response #{request_output.response.env.body}"}
          request_output
        end

        # Overrides #site to insert custom subdomain for API calls.
        def site(*args)
          if !@subdomain.to_s.empty?
            site_uri = URI.parse(super)
            site_uri.host = "#{@subdomain}.#{site_uri.host}"
            logger.debug "(slack) Oauth site uri with custom team_domain #{site_uri}"
            site_uri.to_s
          else
            super
          end
        end

        # Overrides #authorize_url to handle a proc (allowing influence from flow_version).
        def authorize_url(*args)
          debug{"authorize_url args: #{args}"}
          debug{"authorize_url options: #{options}"}
          if options[:authorize_url].is_a?(Proc)
            options[:authorize_url] = instance_eval &(options[:authorize_url])
          end
          debug{"authorize_url resolved: #{options[:authorize_url]}"}
          super
        end
        
        # Overrides #token_url to handle a proc (allowing influence from flow_version).
        def token_url(*args)
          if options[:token_url].is_a?(Proc)
            options[:token_url] = instance_eval &(options[:token_url])
          end
          super
        end
        
      end
    end
  end
end