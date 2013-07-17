require 'rest-core'

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
  # => {"@platform"=>"iPhone", "@name"=>"PicCollage",
  #     "@createdDate"=>"2011-07-24", "@category"=>"Photography",
  #     "@version"=>"1.0", "@generatedDate"=>"9/15/11 7:08 AM",
  #     "version"=>[{"@name"=>"2.1", ...
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
  # >> f.metrics('ActiveUsers', {}, :weeks => 4)
  # => [["2011-09-19",  6516], ["2011-09-18", 43920], ["2011-09-17", 45412],
  #     ["2011-09-16", 40972], ["2011-09-15", 37587], ["2011-09-14", 34918],
  #     ["2011-09-13", 35223], ["2011-09-12", 37750], ["2011-09-11", 45057],
  #     ["2011-09-10", 44077], ["2011-09-09", 36683], ["2011-09-08", 34871],
  #     ["2011-09-07", 35960], ["2011-09-06", 35829], ["2011-09-05", 37777],
  #     ["2011-09-04", 40233], ["2011-09-03", 39306], ["2011-09-02", 33467],
  #     ["2011-09-01", 31558], ["2011-08-31", 32096], ["2011-08-30", 34076],
  #     ["2011-08-29", 34950], ["2011-08-28", 40456], ["2011-08-27", 41332],
  #     ["2011-08-26", 37737], ["2011-08-25", 34392], ["2011-08-24", 33560],
  #     ["2011-08-23", 34722]]
  def metrics path, query={}, opts={}
    get("appMetrics/#{path}", *calculate_query_and_opts(query, opts)
      )['day'].map{ |i| [i['@date'], i['@value'].to_i] }.reverse
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