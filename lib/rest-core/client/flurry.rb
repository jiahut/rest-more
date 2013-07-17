require 'rest-core'

# >> f = RestCore::Flurry.new api_key: xxxxx , access_code: xxxx
module RestCore
  Flurry = Builder.client(:api_key, :access_code) do
    use Timeout       , 10

    use DefaultSite   , 'http://api.flurry.com/'
    use DefaultHeaders, {'Accept' => 'application/json'}
    use DefaultQuery  , {}

    use CommonLogger  , nil
    use Cache         , nil, 600 do
      use ErrorHandler, lambda{|env| raise env[s::RESPONSE_BODY]['message']}
      use ErrorDetector, lambda{ |env|
        env[RESPONSE_BODY].kind_of?(Hash) &&
        (env[RESPONSE_BODY]['error'] || env[RESPONSE_BODY]['error_code'])}

      use JsonResponse, true
    end
  end
end


module RestCore::Flurry::Client
  # see: http://wiki.flurry.com/index.php?title=AppInfo
  # >> f.app_info
  # => {"@platform"=>"iPhone", 
  #     "@name"=>"微点", 
  #     "@createdDate"=>"2013-05-22", 
  #     "@category"=>"Lifestyle", 
  #     "@version"=>"1.0", 
  #     "@generatedDate"=>"7/16/13 9:50 PM", 
  #     "version"=> [
  #       {"@name"=>"1.5", "@createdDate"=>"2013-07-04"}, 
  #       {"@name"=>"1.1", "@createdDate"=>"2013-06-08"}, 
  #       {"@name"=>"1.0", "@createdDate"=>"2013-05-22"}
  #      ]
  #    }

  def app_info query={}
    get('appInfo/getApplication', query)
  end

  # see: http://wiki.flurry.com/index.php?title=EventMetrics
  # >> f.event_matrics({}, :days => 7)
  # => {"Facebook share error"=>{"@usersLastWeek"=>"948",
  #                              "@usersLastMonth"=>"2046",
  #                              "@usersLastDay"=>"4",...}}
  def event_metrics query={}, opts={}
    get('eventMetrics/Summary', *calculate_query_and_opts(query, opts)
      )['event'].inject({}){ |r, i|
        r[i['@eventName']] = i.reject{ |k, _| k == '@eventName' }
        r }
  end

  # see: http://wiki.flurry.com/index.php?title=AppMetrics
  # Where the METRIC_NAME is one of the following:

  # ActiveUsers  Total number of unique users who accessed the application per day.
  # ActiveUsersByWeek  Total number of unique users who accessed the application per week. Only returns data for dates which specify at least a complete calendar week.
  # ActiveUsersByMonth   Total number of unique users who accessed the application per month. Only returns info for dates which specify at least a complete calendar month.
  # NewUsers   Total number of unique users who used the application for the first time per day.
  # MedianSessionLength  Median length of a user session per day.
  # AvgSessionLength   Average length of a user session per day.
  # Sessions   The total number of times users accessed the application per day.
  # RetainedUsers  Total number of users who remain active users of the application per day.
  # PageViews  Total number of page views per day.
  # AvgPageViewsPerSession   Average page views per session for each day.
  # eg:
  # >> f.metrics 'ActiveUsers',{}, :days => 4
  # => [["2013-07-17", 0], ["2013-07-16", 110], ["2013-07-15", 207], ["2013-07-14", 247]]


  def metrics path, query={}, opts={}
    get("appMetrics/#{path}", *calculate_query_and_opts(query, opts)
      )['day'].map{ |i| [i['@date'], i['@value'].to_i] }.reverse
  end

  # bug:
  # assign :days => 1
  def active_users_yesterday
    (metrics 'ActiveUsers', {} ,:days => 2)[1][1]
  end

  def sessions_yesterday
    (metrics 'Sessions', {} ,:days => 2)[1][1]
  end

  # >> f.weekly(f.metrics('ActiveUsers', {}, :weeks => 4))
  # => [244548, 270227, 248513, 257149]
  def weekly array
    start = Time.parse(array.first.first, nil).to_i
    array.group_by{ |(date, value)|
      current = Time.parse(date, nil).to_i
      - (current - start) / (86400*7)
    # calling .last to discard week numbers created by group_by
    }.sort.map(&:last).map{ |week|
      week.map{ |(date, num)| num }.inject(&:+) }
  end

  # >> f.sum(f.weekly(f.metrics('ActiveUsers', {}, :weeks => 4)))
  # => [1020437, 775889, 505662, 257149]
  def sum array
    reverse = array.reverse
    (0...reverse.size).map{ |index|
      reverse[1, index].inject(reverse.first, &:+)
    }.reverse
  end

  def query
    {'apiKey'        => api_key    ,
     'apiAccessCode' => access_code}
  end

  private
  def calculate_query_and_opts query, opts
    days = opts[:days] || (opts[:weeks]  && opts[:weeks] * 7)   ||
                          (opts[:months] && opts[:months] * 30)

    startDate = query[:startDate] || (Time.now + 86400 - 86400*days).
      strftime('%Y-%m-%d')

    endDate   = query[:endDate]   || Time.now.
      strftime('%Y-%m-%d')

    [query.merge(:startDate => startDate,
                 :endDate   => endDate),
     opts.reject{ |k| [:days, :weeks, :months].include?(k) }]
  end
end

class RestCore::Flurry
  include RestCore::Flurry::Client
end