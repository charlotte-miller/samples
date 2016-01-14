require 'net/ssh/gateway'
Dir[Rails.root.join("lib/legacy_adapters/**/*.rb")].each {|f| require f}

namespace "legacy_site" do

  desc "Migrates Pages from the Legacy Site"
  task "pages" => 'environment' do
    open_tunnel do
      LegacyPage.db_setup "cornerstone_sf_org_#{Rails.env}", 'simple_cms_navigation'
      LegacyPage.update_or_create_recent_pages
      Page::LegacyIntegration.audit_urls
    end


  end


  desc "Migrates Media from the Legacy Site"
  task "media" => 'environment' do
    open_tunnel do
      LegacyChannel.db_setup "cornerstone_sf_org_#{Rails.env}",  'tv_channel'
      LegacySeries.db_setup  "cornerstone_sf_org_#{Rails.env}",  'tv_series'
      LegacyMedia.db_setup   "cornerstone_sf_org_#{Rails.env}",  'tv_mediaitem'

      [LegacyChannel, LegacySeries, LegacyMedia].each(&:update_all)
    end
  end
end

def open_tunnel
  if Rails.env.production?
    auth_key = ENV['LEGACY_ACCESS_KEY'] || File.read(Rails.root.join('config/legacy_access/sporos'))
    gateway = Net::SSH::Gateway.new( '173.230.153.98', 'cornerstonesf', key_data: auth_key)
    gateway.open('127.0.0.1', 5432, 9000)
    fork do
      yield
    end
    Process.wait
    gateway.shutdown!
  else
    yield
  end
end
