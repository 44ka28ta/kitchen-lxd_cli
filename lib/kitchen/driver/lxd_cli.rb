# -*- encoding: utf-8 -*-
#
# Author:: Braden Wright (<braden.m.wright@gmail.com>)
#
# Copyright (C) 2015, Braden Wright
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'kitchen'

module Kitchen

  module Driver

    # LxdCli driver for Kitchen.
    #
    # @author Braden Wright <braden.m.wright@gmail.com>
    class LxdCli < Kitchen::Driver::SSHBase
      default_config :public_key_path do
        [
          File.expand_path('~/.ssh/id_rsa.pub'),
          File.expand_path('~/.ssh/id_dsa.pub'),
          File.expand_path('~/.ssh/identity.pub'),
          File.expand_path('~/.ssh/id_ecdsa.pub')
        ].find { |path| File.exist?(path) }
      end

      def create(state)
        if exists?
          if running?
            debug("#{instance.name} already exists, and is already running.  Nothing to do")
          else
            debug("#{instance.name} already exists, starting instead")
            run_command("lxc start #{instance.name}")
          end
        else
          create_image_if_missing
          run_command("lxc launch #{instance.platform.name} #{instance.name}")
        end
        ip_address(state)
        setup_ssh_access
      end

      def destroy(state)
        if exists?
          if running?
            run_command("lxc stop #{instance.name}")
          else
            debug("#{instance.name} isn't running, just destroying instead")
          end
          run_command("lxc delete #{instance.name}")
        else
          debug("#{instance.name} doesn't exist.  Nothing to do")
        end
        state.delete(:hostname)
      end

      private
        def exists?
          status = `lxc info #{instance.name} > /dev/null 2>&1 && echo $?`.chomp
          if "#{status}" == "0"
            debug("#{instance.name} exists")
            return true
          else
            debug("#{instance.name} doesn't exist")
            return false
          end
        end

        def running?
          status = `lxc info #{instance.name}`.match(/Status: ([a-zA-Z]+)[\n]/).captures[0].upcase
          if status == "RUNNING"
            debug("#{instance.name} is running")
            return true
          else
            debug("#{instance.name} isn't running")
            return false
          end
        end

        def create_image_if_missing
          status = `lxc image show #{instance.name} > /dev/null 2>&1 && echo $?`.chomp
          if "#{status}" == "0"
            debug("Image #{instance.name} exists")
            return false
          else
            debug("Image #{instance.name} doesn't exist, creating now.")
            image = get_ubuntu_image_info
            debug("lxd-images import #{image[:os]} #{image[:release]} --alias #{instance.platform.name}")
            run_command("lxd-images import #{image[:os]} #{image[:release]} --alias #{instance.platform.name}")
            return true
          end
        end

        def get_ubuntu_image_info
          platform, release = instance.platform.name.split('-')
          if platform.downcase == "ubuntu"
            case release.downcase
            when "14.04", "1404", "trusty", "", nil
              image = { :os => platform, :release => "trusty" }
            when "14.10", "1410", "utopic"
              image = { :os => platform, :release => "utopic" }
            when "15.04", "1504", "vivid"
              image = { :os => platform, :release => "vivid" }
            when "15.10", "1510", "wily"
              image = { :os => platform, :release => "wily" }
            when "16.04", "1604", "xenial"
              image = { :os => platform, :release => "xenial" }
            else
              image = { :os => platform, :release => release }
            end
            return image
          end
        end

        def ip_address(state)
          begin
            lxc_info = `lxc info #{instance.name}`
          end while (!lxc_info.match(/eth0:[\t]IPV[46][\t]([0-9.]+)[\n]/))
          lxc_ip = lxc_info.match(/eth0:[\t]IPV[46][\t]([0-9.]+)[\n]/).captures[0].to_s
          state[:hostname] = lxc_ip
          return lxc_ip
        end

        def setup_ssh_access
          info("Copying public key from #{config[:public_key_path]} to #{instance.name}")
          begin
            sleep 1
            status = `lxc file push #{config[:public_key_path]} #{instance.name}/root/.ssh/authorized_keys 2> /dev/null && echo $?`.chomp
          end while ("#{status}" != "0")
        end
    end
  end
end