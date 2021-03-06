
require 'rest-core'

# http://developer.linkedin.com/documents/linkedin-api-resource-map
module RestCore
  Linkedin = Builder.client do
    use Timeout       , 10

    use DefaultSite   , 'https://api.linkedin.com/'
    use DefaultHeaders, {'Accept' => 'application/json'}
    use DefaultQuery  , {'format' => 'json'}

    use Oauth1Header  ,
      'uas/oauth/requestToken', 'uas/oauth/accessToken',
      'https://www.linkedin.com/uas/oauth/authorize'

    use CommonLogger  , nil
    use Cache         , nil, 600 do
      use ErrorHandler, lambda{ |env|
        RuntimeError.new(env[RESPONSE_BODY]['message'])}
      use ErrorDetectorHttp
      use JsonResponse, true
    end
  end
end

module RestCore::Linkedin::Client
  include RestCore

  def me query={}, opts={}
    get('v1/people/~', query, opts)
  end

  def authorize_url
    url(authorize_path, :oauth_token => oauth_token, :format => false)
  end
end

class RestCore::Linkedin
  include RestCore::ClientOauth1
  include RestCore::Linkedin::Client

  autoload :RailsUtil, 'rest-core/client/linkedin/rails_util' if
    Object.const_defined?(:Rails)
end
