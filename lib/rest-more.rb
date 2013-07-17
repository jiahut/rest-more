
require 'rest-core'

module RestCore
  autoload :Config  , 'rest-core/util/config'

  autoload :Dropbox , 'rest-core/client/dropbox'
  autoload :Facebook, 'rest-core/client/facebook'
  autoload :Github  , 'rest-core/client/github'
  autoload :Linkedin, 'rest-core/client/linkedin'
  autoload :Twitter , 'rest-core/client/twitter'
  autoload :Flurry  , 'rest-core/client/flurry'
end
