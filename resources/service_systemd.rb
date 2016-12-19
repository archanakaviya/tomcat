provides :tomcat_service_systemd

provides :tomcat_service, platform: 'fedora'

provides :tomcat_service, os: 'linux' do |_node|
  Chef::Platform::ServiceHelpers.service_resource_providers.include?(:systemd)
end

property :instance_name, String, name_property: true
property :install_path, String
property :tomcat_user, String, default: lazy { |r| "tomcat_#{r.instance_name}" }
property :tomcat_group, String, default: lazy { |r| "tomcat_#{r.instance_name}" }
property :env_vars, Array, default: [
  { 'CATALINA_PID' => '$CATALINA_BASE/bin/tomcat.pid' }
]
property :sensitive, [true, false], default: false

action :start do
  create_init

  service "tomcat_#{new_resource.instance_name}" do
    provider Chef::Provider::Service::Systemd
    supports restart: true, status: true
    action :start
    only_if 'command -v java >/dev/null 2>&1 || exit 1'
  end
end

action :stop do
  service "tomcat_#{new_resource.instance_name}" do
    provider Chef::Provider::Service::Systemd
    supports status: true
    action :stop
    only_if { ::File.exist?("/etc/systemd/system/tomcat_#{new_resource.instance_name}.service") }
  end
end

action :restart do
  service "tomcat_#{new_resource.instance_name}" do
    provider Chef::Provider::Service::Systemd
    supports status: true
    action :restart
  end
end

action :disable do
  service "tomcat_#{new_resource.instance_name}" do
    provider Chef::Provider::Service::Systemd
    supports status: true
    action :disable
    only_if { ::File.exist?("/etc/systemd/system/tomcat_#{new_resource.instance_name}.service") }
  end
end

action :enable do
  create_init

  service "tomcat_#{new_resource.instance_name}" do
    provider Chef::Provider::Service::Systemd
    supports status: true
    action :enable
    only_if { ::File.exist?("/etc/systemd/system/tomcat_#{new_resource.instance_name}.service") }
  end
end

action_class.class_eval do
  def create_init
    ensure_catalina_base

    template "/etc/systemd/system/tomcat_#{instance_name}.service" do
      source 'init_systemd.erb'
      sensitive new_resource.sensitive
      variables(
        instance: new_resource.instance_name,
        env_vars: new_resource.env_vars,
        install_path: derived_install_path,
        user: new_resource.tomcat_user,
        group: new_resource.tomcat_group
      )
      cookbook 'tomcat'
      owner 'root'
      group 'root'
      mode '0644'
      notifies :run, 'execute[Load systemd unit file]', :immediately
      notifies :restart, "service[tomcat_#{new_resource.instance_name}]"
    end

    execute 'Load systemd unit file' do
      command 'systemctl daemon-reload'
      action :nothing
    end
  end
end
