# vertquery -- a one-page tool for pasting a request straight at a GeoService
# (see vertbase's docs/api/geo_query_spec.md) and seeing the raw response back.
# Run with: bundle exec ruby app.rb   (defaults to http://localhost:4567)

require "sinatra"
require "net/http"
require "json"
require "uri"
require "cgi"

set :port, ENV.fetch("PORT", 4567)

EXAMPLE_QUERY = JSON.pretty_generate(
  "type" => "FeatureCollection",
  "features" => [
    {
      "type" => "Feature",
      "id" => "asset-001",
      "properties" => { "name" => "San Diego Office" },
      "geometry" => { "type" => "Point", "coordinates" => [-117.1611, 32.7157] }
    }
  ]
)

helpers do
  def h(text)
    CGI.escapeHTML(text.to_s)
  end
end

get "/" do
  @base_url = "http://localhost:9898"
  @api_key  = ""
  @query    = EXAMPLE_QUERY
  @status   = nil
  @result   = nil
  @error    = nil
  erb :index
end

post "/" do
  @base_url = params[:base_url].to_s.strip
  @api_key  = params[:api_key].to_s
  @query    = params[:query].to_s
  @status   = nil
  @result   = nil
  @error    = nil

  begin
    uri = URI.join(@base_url.sub(%r{/*\z}, "/"), "api/v1/geo_queries")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 15

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@api_key}"
    request["Content-Type"]  = "application/json"
    request.body = @query

    response = http.request(request)
    @status = "#{response.code} #{response.message}"
    @result = begin
      JSON.pretty_generate(JSON.parse(response.body))
    rescue JSON::ParserError
      response.body
    end
  rescue StandardError => e
    @error = "#{e.class}: #{e.message}"
  end

  erb :index
end

__END__

@@ index
<!DOCTYPE html>
<html>
<head>
  <title>vertquery</title>
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <style>
    body {
      background: #0a140c;
      color: #a3e085;
      font-family: ui-monospace, "SF Mono", "Courier New", Menlo, Consolas, monospace;
      max-width: 900px;
      margin: 24px auto;
      padding: 0 16px;
    }
    h1 { font-size: 1.2em; }
    label { display: block; margin: 14px 0 4px; }
    input, textarea {
      width: 100%;
      background: #10200f;
      color: #c9f5ae;
      border: 1px solid #4c9626;
      font-family: inherit;
      font-size: 0.95em;
      padding: 6px 8px;
      box-sizing: border-box;
    }
    textarea { height: 220px; resize: vertical; }
    button {
      margin-top: 14px;
      background: #4c9626;
      color: #06170a;
      border: none;
      padding: 8px 16px;
      font-family: inherit;
      font-weight: bold;
      cursor: pointer;
    }
    button:hover { background: #9fe870; }
    .row { display: flex; gap: 16px; }
    .row > div { flex: 1; }
    .status { margin-top: 20px; font-weight: bold; }
    .error { color: #e88a6a; }
    pre {
      background: #10200f;
      border: 1px solid #4c9626;
      padding: 10px;
      overflow-x: auto;
      white-space: pre-wrap;
      word-break: break-word;
    }
  </style>
</head>
<body>
  <h1>vertquery</h1>
  <p>Send a request body straight to a GeoService's <code>/api/v1/geo_queries</code> endpoint and see exactly what comes back.</p>

  <form method="post" action="/">
    <div class="row">
      <div>
        <label for="base_url">GeoService base URL</label>
        <input id="base_url" name="base_url" type="text" value="<%= h @base_url %>">
      </div>
      <div>
        <label for="api_key">API key</label>
        <input id="api_key" name="api_key" type="password" value="<%= h @api_key %>">
      </div>
    </div>

    <label for="query">Request body (JSON)</label>
    <textarea id="query" name="query"><%= h @query %></textarea>

    <button type="submit">Send</button>
  </form>

  <% if @error %>
    <div class="status error">Request failed: <%= h @error %></div>
  <% elsif @status %>
    <div class="status">Response: <%= h @status %></div>
    <pre><%= h @result %></pre>
  <% end %>
</body>
</html>
