node[:deploy].each do |application, deploy|
  if deploy['sidekiq']
    sidekiq_config = deploy['sidekiq']
    release_path = ::File.join(deploy[:deploy_to], 'current')
    start_command = sidekiq_config['start_command'] || "bundle exec sidekiq -i ${index} -e production -C config/sidekiq.yml -r ./config/boot.rb 2>&1 >> log/sidekiq.log"
    env = deploy['environment_variables'] || { "HOME" => "/home/#{deploy[:user]}"}

    template "setup sidekiq.conf" do
      path "/etc/init/sidekiq-#{application}.conf"
      source "sidekiq.conf.erb"
      owner "root"
      group "root"
      mode 0644
      variables({
        app_name: application,
        user: deploy[:user],
        group: deploy[:group],
        release_path: release_path,
        start_command: start_command,
        env: env,
      })
    end

    template "setup workers.conf" do
      path "/etc/init/workers-#{application}.conf"
      source "workers.conf.erb"
      owner "root"
      group "root"
      mode 0644
      variables({
        app_name: application,
        num_workers: sidekiq_config['num_workers'] || 2
      })
    end

    service "workers-#{application}" do
      provider Chef::Provider::Service::Upstart
      supports stop: true, start: true, restart: true
    end

    # always restart sidekiq on deploy since we assume the code must need to be reloaded
    bash 'restart_sidekiq' do
      code "echo noop"
      notifies :restart, "service[workers-#{application}]"
    end
  end
end
