geonode_pkgs =  "build-essential libxml2-dev libxslt-dev libjpeg-dev zlib1g-dev libpng12-dev libpq-dev python-dev maven".split

geonode_pkgs.each do |pkg|
  package pkg do
    action :install
  end
end

include_recipe 'rogue::permissions'
include_recipe 'rogue::java'
include_recipe 'rogue::tomcat'
include_recipe 'rogue::nginx'
include_recipe 'rogue::geogit'
include_recipe 'rogue::networking'
include_recipe 'rogue::unison'

source = "/usr/lib/x86_64-linux-gnu/libjpeg.so"
target = "/usr/lib/libjpeg.so"
# This fixes https://github.com/ROGUE-JCTD/rogue_geonode/issues/17
link target do
  to source
  not_if do File.exists?(target) or !File.exists?(source) end
  action :create
end

include_recipe 'rogue::database'

rogue_geonode node['rogue']['geonode']['location'] do
  action :install
end

include_recipe 'rogue::geoserver_data'
include_recipe 'rogue::geoserver'
include_recipe 'rogue::fileservice'

template "nginx_proxy_config" do
  path File.join(node['nginx']['dir'], 'proxy.conf')
  source 'proxy.conf.erb'
end

template "rogue_geonode_nginx_config" do
  path "#{node['nginx']['dir']}/sites-enabled/nginx.conf"
  source "nginx.conf.erb"
  variables ({:proxy_conf => "#{node['nginx']['dir']}/proxy.conf"})
  notifies :reload, "service[nginx]", :immediately
end

# Create the GeoGIT datastore directory
directory node['rogue']['rogue_geonode']['settings']['OGC_SERVER']['GEOGIT_DATASTORE_DIR'] do
  owner node['tomcat']['user']
  recursive true
  mode 00755
end

rogue_geonode node['rogue']['geonode']['location'] do
 action [:sync_db, :load_data, :update_layers, :start]
end

log "Rogue is now running on #{node['rogue']['networking']['application']['address']}."
