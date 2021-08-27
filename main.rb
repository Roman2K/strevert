require 'utils'

class Syncthing
  def initialize(url, api_key, log:)
    @http = Utils::SimpleHTTP.new "#{url}/rest", json: true, log: log["http"]
    @http.req_filters << -> req {
      req["X-API-Key"] = api_key
    }
  end

  def folders
    @http.get("/system/config").fetch "folders"
  end

  def revert(folder)
    @http.post ["/db/revert", folder: folder.fetch("id")], nil,
      expect: [Net::HTTPOK],
      json_out: false
  end
end

if $0 == __FILE__
  conf = Utils::Conf.new "config.yml"
  log = Utils::Log.new level: ENV["DEBUG"] == "1" ? :debug : :info
  url = conf[:url]
  log[url: url].info "starting"
  st = Syncthing.new url, conf[:api_key], log: log["Syncthing"]

  folders = st.folders.
    select { |f| f.fetch("type") == "receiveonly" }.
    tap { |fs| !fs.empty? or raise "no receive-only folders found" }.
    map { |f| f.slice "id", "label" }

  log.info "found #{folders.size} receive-only folders"

  folders.each do |f|
    log[folder: f.fetch("label")].info "reverting local changes" do
      st.revert f
    end
  end
end
