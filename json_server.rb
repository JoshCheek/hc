path_to_my_server = '/Users/josh/code/jsl/lesson_plans/electives/building-a-webserver/server-from-class/lib/http_yeah_you_know_me'
require_relative path_to_my_server

app = lambda { |env|
  json    = File.read('/Users/josh/deleteme/headcounts/josh_headcount/data/districts.json')
  headers = {'Content-Type' => 'application/json', 'Content-Length' => json.length}
  [200, headers, [json]]
}

server = HttpYeahYouKnowMe.new(9292, app)
at_exit { server.stop }
server.start
