begin
  require 'vagrant'
rescue LoadError
  raise 'The Vagrant RancherOs VirtualBox Additions plugin must be run within Vagrant'
end

begin
  require 'ipaddr'
rescue LoadError
  raise 'The Vagrant RancherOs VirtualBox Additions plugin must load ipaddr module'
end

begin
  require "shellwords"
rescue LoadError
  raise 'The Vagrant RancherOs VirtualBox Additions plugin must load shellwords module'
end

begin
  require "vagrant/util/retryable"
rescue LoadError
  raise 'The Vagrant RancherOs VirtualBox Additions plugin must load vagrant retryable module'
end

begin
  require "vagrant/guest"
rescue LoadError
  raise 'The Vagrant RancherOs VirtualBox Additions plugin must load vagrant guest module'
end

begin
  require "vagrant/plugin"
rescue LoadError
  raise 'The Vagrant RancherOs VirtualBox Additions plugin must load vagrant guest module'
end

IPAddr.class_eval do
  def to_cidr
    to_i.to_s(2).count('1')
  end
end
#guest 'linux' do
#  require_relative 'guest'
#  RancherosGuest
#end
module VagrantPlugins
  module GuestLinux
    class Plugin < Vagrant.plugin('2')
      name "RancherOS guest."
      description <<-DESC
      A Vagrant plugin to automate RancherOS Virtual Box Additions commands.
      DESC
      def detect?(machine)
        machine.communicate.test('cat /usr/bin/system-docker')
      end

      guest_capability 'linux', 'change_host_name' do
        #require_relative 'cap/change_host_name'
        Cap::ChangeHostName
      end

      guest_capability 'linux', 'configure_networks' do
        #require_relative 'cap/configure_networks'
        Cap::ConfigureNetworks
      end
      guest_capability 'linux', 'configure_dns' do
        #require_relative 'cap/configure_dns'
        Cap::ConfigureDNS
      end
      guest_capability('linux', 'choose_addressable_ip_addr') do
        #require_relative "cap/choose_addressable_ip_addr"
        Cap::ChooseAddressableIPAddr
      end
      guest_capability('linux', 'halt') do
        #require_relative "cap/halt"
        Cap::Halt
      end
      guest_capability('linux', 'mount_virtualbox_shared_folder') do
        #require_relative "cap/mount_virtualbox_shared_folder"
        Cap::MountVirtualBoxSharedFolder
      end
      guest_capability('linux', 'unmount_virtualbox_shared_folder') do
        #require_relative "cap/mount_virtualbox_shared_folder"
        Cap::MountVirtualBoxSharedFolder
      end
    end
    module Cap
      class ConfigureNetworks
        def self.change_authorized_keys(machine)
          machine.ui.info("Changing authorized keys in Rancher OS ...")
          machine.communicate.tap do |comm|
            @base_name = ".authorized_keys"
            @base_path = File.realpath( ".").to_s
            @auth_keys_file = @base_path + "/" + @base_name
            if (File.exist?(@auth_keys_file) == true) then
              @authorized_keys = []
              File.readlines(@auth_keys_file).map do |line|
                if (line.strip != '') then
                  @authorized_keys << line.strip
                end
                #line.split.map(&:to_i)
              end
              machine.ui.info("New authorized keys number : #{@authorized_keys.length}")
              if @authorized_keys.length > 0 then
                @auth_keys = @authorized_keys.join("\n")
                @auth_ssh_keys_value = "'#{@authorized_keys.join("','")}'"
                machine.ui.warn("Saving authorized keys : \n#{@auth_keys}")
                comm.upload(@auth_keys_file, "/home/rancher/.ssh/authorized_keys")
                comm.sudo("chown -f rancher:rancher /home/rancher/.ssh/authorized_keys")
                comm.sudo("cp /home/rancher/.ssh/authorized_keys /root/.ssh/authorized_keys")
                comm.sudo("ros config set ssh_authorized_keys [#{@auth_ssh_keys_value}]")
                # comm.sudo("mv /home/rancher/.ssh/.authorized_keys /home/rancher/.ssh/authorized_keys")
                machine.ui.warn("Authorized keys changes applyed succesfully!!")
              else
                machine.ui.warn("File #{@auth_keys_file} doesn't contain dns names, no changes available ... ")
              end
            else
              machine.ui.warn("File #{@auth_keys_file} doesn't exists!!")
              machine.ui.warn("No authorized keys change will be applied.")
            end
          end
        end
        def self.configure_networks(machine, networks)
          machine.communicate.tap do |comm|
            interfaces = []
            comm.sudo("ip link show|grep eth[1-9]|awk '{print $2}'|sed -e 's/:$//'") do |_, result|
              interfaces = result.split("\n")
            end

            machine.ui.info("Applying IP addresses : #{interfaces.join(', ')}")

            networks.each do |network|
              # Dynamic networks uses dhcp
              dhcp = "true"
              iface = interfaces[network[:interface].to_i - 1]
              machine.ui.warn("Applying network for interface : #{iface}")

              if network[:type] == :static
                cidr = IPAddr.new(network[:netmask]).to_cidr
                machine.ui.warn("Applying static network for interface : #{network[:ip]}/#{cidr}")
                comm.sudo("ros config set rancher.network.interfaces.#{iface}.address #{network[:ip]}/#{cidr}")
                comm.sudo("ros config set rancher.network.interfaces.#{iface}.match #{iface}")
                # Static networks doesn't need dhcp
                dhcp = "false"
              end
              comm.sudo("ros config set rancher.network.interfaces.#{iface}.dhcp #{dhcp}")
            end
            # comm.sudo("cat /etc/ssh/sshd_config | sed 's/#AuthorizedKeysFile/AuthorizedKeysFile/g' > /etc/ssh/sshd_config")
            # comm.sudo("/etc/init.d/ssh restart")
            # comm.sudo("ros config set rancher.network.interfaces.br0.bridge true")
            # comm.sudo("ros config set rancher.network.interfaces.br0.dhcp true")
            # comm.sudo("ros config set rancher.network.interfaces.br1.bridge true")
            # comm.sudo("ros config set rancher.network.interfaces.br1.dhcp true")
            # @base_nets = []
            # @base_name = ".system_network"
            # @base_path = File.realpath( ".").to_s
            # @base_net_file = @base_path + "/" + @base_name
            # if (File.exist?(@base_net_file) == true) then
            #   File.readlines(@base_net_file).map do |line|
            #     if (line.strip != '') then
            #       @base_nets << line.strip
            #     end
            #     #line.split.map(&:to_i)
            #   end
            # end
            # if @base_nets.length > 0 then
            #
            # end
            comm.sudo("system-docker restart network")
          end
          self.change_authorized_keys machine
        end #
      end
      class ChangeHostName
        def self.installRancherOsConsoleAndWait(machine, comm, console)
          comm.sudo("ros console switch -f #{console}")
          sleep 5
          @retrial = 0
          @do_not_timeout = true
          while @do_not_timeout && comm.test("if [ -z $(sudo ros console list | grep '#{console}' | grep 'current')]; then exit 1; fi") == false do
            if @retrial > 12 then
              @do_not_timeout = false
            end
            machine.ui.warn("RancherOS not yet available!!")
            @retrial += 1;
            sleep 10 #wait 10 seconds (totally 120)
          end
        end
        def self.checkSwitchConsole(machine)
          @base_name = ".rancheros_console"
          @base_path = File.realpath( ".").to_s
          @console_file = @base_path + "/" + @base_name
          @default_console = "ubuntu"
          if File.exist?(@console_file)  then
            @console = ""
            File.readlines(@console_file).map do |line|
              if (line.strip != '' ) then
                @console = line.strip
              end
            end
            if (@console != "") then
              machine.communicate.tap do |comm|
                @existsConsole = comm.test("if [ -z $(sudo ros console list | grep '#{@console}')]; then exit 1; fi")
                if @existsConsole then
                  @presentConsole = comm.test("if [ -z $(sudo ros console list | grep '#{@console}' | grep 'current')]; then exit 1; fi")
                  unless @presentConsole then
                    machine.ui.info("Applying RancherOS console : #{@console}")
                    self.installRancherOsConsoleAndWait machine, comm, @console
                  else
                    machine.ui.warn("RancherOS console : #{@console} already present!!")
                  end
                else
                  machine.ui.warn("RancherOS console : #{@console} unknown!!")
                  machine.ui.warn("Please access to the virtual machine, type : sudo ros console list, and correct the #{@base_name} file")
                  # output = {stdout: ':stdout', stderr: ''}
                  # comm.execute("sudo ros console list | awk 'BEGIN {FS = OFS = \" \"} {print $2}'", output: output[:stdout])
                end
              end
            else
              machine.ui.warn("No RancherOS console specified in file : #{@console_file}")
              machine.communicate.tap do |comm|
                @presentConsole = comm.test("if [ -z $(sudo ros console list | grep '#{@default_console}' | grep 'current')]; then exit 1; fi")
                unless @presentConsole then
                  machine.ui.warn("Installing default console : #{@default_console}")
                  self.installRancherOsConsoleAndWait machine, comm, @default_console
                else
                  machine.ui.warn("RancherOS default console : #{@default_console} already present!!")
                end
              end
            end
          else
            machine.ui.warn("No RancherOS console file specified (#{@console_file}) ...")
            machine.communicate.tap do |comm|
              @presentConsole = comm.test("if [ -z $(sudo ros console list | grep '#{@default_console}' | grep 'current')]; then exit 1; fi")
              unless @presentConsole then
                machine.ui.warn("Installing default console : #{@default_console}")
                self.installRancherOsConsoleAndWait machine, comm, @default_console
              else
                machine.ui.warn("RancherOS default console : #{@default_console} already present!!")
              end
            end
          end
        end
        def self.checkSSHFSIntegration(machine)
          @base_name = ".sshfs_enabled"
          @base_path = File.realpath( ".").to_s
          @sshfs_enmabled_file = @base_path + "/" + @base_name
          if File.exist?(@sshfs_enmabled_file)  then
            machine.ui.info("SSHFS Protocol installation required, now checking the availability of the protocol ...")
            machine.communicate.tap do |comm|
              @exists_sshfs = comm.test("sshfs -V")
              if @exists_sshfs == false then
                machine.ui.info("SSHFS protocol not enabled ... Proceeding with installation!!")
                @presentDefaultConsole = comm.test("if [ -z $(sudo ros console list | grep 'default' | grep 'current')]; then exit 1; fi")
                if @presentDefaultConsole then
                  @console = "ubuntu"
                  machine.ui.warn("SSHFS Protocol install - Applying RancherOS console : #{@console}")
                  self.installRancherOsConsoleAndWait machine, comm, @console
                end
                machine.ui.info("SSHFS Protocol software installation ...")
                comm.sudo("apt-get update")
                comm.sudo("apt-get install -y sshfs")
                comm.sudo("apt-get -y autoremove &&  apt-get -y clean &&  rm -rf /var/lib/apt/lists/*")
                machine.ui.warn("SSHFS protocol intalled ...")
              else
                machine.ui.warn("SSHFS protocol already enabled ...")
              end
            end
          end
        end
        def self.change_host_name(machine, name)
          machine.communicate.tap do |comm|
            machine.ui.info("Changing hostname to : #{name.split('.')[0]}")
            @presentEtcHostName = comm.test("if [ -z $(sudo sed -n \"/#{name.split('.')[0]}/p\" /etc/hosts)]; then exit 1; fi")
            @presentHostName = comm.test("if [ -z $(sudo hostname --fqdn | grep '#{name}')]; then exit 1; fi")
            unless @presentEtcHostName then
              comm.sudo("cat /etc/hosts | sed \"/rancher/ s/.*/127.0.0.1\t#{name.split('.')[0]}/g\" > /etc/hosts.new")
              comm.sudo("cat /etc/hosts.new > /etc/hosts")
              comm.sudo("rm -f /etc/hosts.new")
              machine.ui.warn("Restaring RancherOS network");
              comm.sudo("system-docker restart network")
              machine.ui.warn("Applied HostName : #{name.split('.')[0]}")
            else
              machine.ui.warn("Hostname already changed to : #{name.split('.')[0]}")
            end
            unless @presentHostName then
              comm.sudo("ros config set hostname #{name.split('.')[0]}")
              machine.ui.warn("Restaring RancherOS network");
              comm.sudo("system-docker restart network")
              machine.ui.warn("Applied HostName in Rancher shell : #{name.split('.')[0]}")
            else
              machine.ui.warn("Hostname already present in Rancher shell as : #{name.split('.')[0]}")
            end
            ChangeHostDNS::change_dns machine

            self.checkSwitchConsole machine

            self.checkSSHFSIntegration machine
          end
        end
      end
      class ChangeHostDNS
        def self.change_dns(machine)
          machine.ui.info("Changing DNS names in Rancher OS ...")
          machine.communicate.tap do |comm|
            @base_name = ".dnsnames"
            @base_path = File.realpath( ".").to_s
            @dns_file = @base_path + "/" + @base_name
            if (File.exist?(@dns_file) == true) then
              @dns_names = []
              File.readlines(@dns_file).map do |line|
                if (line.strip != '') then
                  @dns_names << line.strip
                end
                #line.split.map(&:to_i)
              end
              machine.ui.info("New DNS names : #{@dns_names.join(', ')}")
              if @dns_names.length > 0 then
                @dns = "'" + @dns_names.join("', '") + "'"
                comm.sudo("ros config set rancher.network.dns.nameservers \"[#{@dns}]\"")
                machine.ui.warn("Restaring RancherOS network");
                comm.sudo('system-docker restart network')
              else
                machine.ui.warn("File #{@dns_file} doesn't contain dns names, so cleaning the rancher os dns list ... ")
                comm.sudo("ros config set rancher.network.dns.nameservers \"\"")
                machine.ui.warn("Restaring RancherOS network");
                comm.sudo('system-docker restart network')
              end
              machine.ui.warn("DNS names changes applyed succesfully!!")
            else
              machine.ui.warn("File #{@dns_file} doesn't exists!!")
              machine.ui.warn("No DNS names change will be applied.")
            end
          end
        end
      end
      class ChooseAddressableIPAddr
        def self.choose_addressable_ip_addr(machine, possible)
          comm = machine.communicate

          possible.each do |ip|
            if comm.test("ping -c1 -w1 -W1 #{ip}")
              return ip
            end
          end

          return nil
        end
      end
      class Halt
        def self.halt(machine)
          begin
            machine.communicate.sudo("poweroff")
          rescue IOError, Vagrant::Errors::SSHDisconnected
            # Do nothing, because it probably means the machine shut down
            # and SSH connection was lost.
          end
        end
      end
      class MountVirtualBoxSharedFolder

        extend Vagrant::Util::Retryable

        def self.mount_virtualbox_shared_folder(machine, name, guestpath, options)
          expanded_guest_path = machine.guest.capability(
          :shell_expand_guest_path, guestpath)

          mount_commands = []

          if options[:owner].is_a? Integer
            mount_uid = options[:owner]
          else
            mount_uid = "`id -u #{options[:owner]}`"
          end

          if options[:group].is_a? Integer
            mount_gid = options[:group]
            mount_gid_old = options[:group]
          else
            mount_gid = "`getent group #{options[:group]} | cut -d: -f3`"
            mount_gid_old = "`id -g #{options[:group]}`"
          end

          # First mount command uses getent to get the group
          mount_options = "-o uid=#{mount_uid},gid=#{mount_gid}"
          mount_options += ",#{options[:mount_options].join(",")}" if options[:mount_options]
          mount_commands << "mount.vboxsf #{mount_options} #{name} #{expanded_guest_path}"

          # Second mount command uses the old style `id -g`
          mount_options = "-o uid=#{mount_uid},gid=#{mount_gid_old}"
          mount_options += ",#{options[:mount_options].join(",")}" if options[:mount_options]
          mount_commands << "mount.vboxsf #{mount_options} #{name} #{expanded_guest_path}"

          # Create the guest path if it doesn't exist
          machine.communicate.sudo("mkdir -p #{expanded_guest_path}")

          # Attempt to mount the folder. We retry here a few times because
          # it can fail early on.
          attempts = 0
          while true
            success = true

            stderr = ""
            mount_commands.each do |command|
              no_such_device = false
              stderr = ""
              status = machine.communicate.sudo(command, error_check: false) do |type, data|
                if type == :stderr
                  no_such_device = true if data =~ /No such device/i
                  stderr += data.to_s
                end
              end

              success = status == 0 && !no_such_device
              break if success
            end

            break if success

            attempts += 1
            if attempts > 5
              raise Vagrant::Errors::LinuxMountFailed,
              command: mount_commands.join("\n"),
              output: stderr
            end

            sleep(2*attempts)
          end

          # Chown the directory to the proper user. We skip this if the
          # mount options contained a readonly flag, because it won't work.
          if !options[:mount_options] || !options[:mount_options].include?("ro")
            chown_commands = []
            chown_commands << "chown #{mount_uid}:#{mount_gid} #{expanded_guest_path}"
            chown_commands << "chown #{mount_uid}:#{mount_gid_old} #{expanded_guest_path}"

            exit_status = machine.communicate.sudo(chown_commands[0], error_check: false)
            machine.communicate.sudo(chown_commands[1]) if exit_status != 0
          end

          # Emit an upstart event if we can
          if machine.communicate.test("test -x /sbin/initctl")
            machine.communicate.sudo(
            "/sbin/initctl emit --no-wait vagrant-mounted MOUNTPOINT=#{expanded_guest_path}")
          end
        end

        def self.unmount_virtualbox_shared_folder(machine, guestpath, options)
          result = machine.communicate.sudo(
          "umount #{guestpath}", error_check: false)
          if result == 0
            machine.communicate.sudo("rmdir #{guestpath}", error_check: false)
          end
        end
      end
    end
  end
end
