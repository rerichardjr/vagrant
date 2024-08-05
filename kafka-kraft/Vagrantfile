require "yaml"
settings = YAML.load_file "settings.yaml"

NODE_COUNT = settings["hosts"]["count"]
NETWORK = settings["ip"]["network"]
HOST_START = settings["ip"]["host_start"]
SCALA_VERSION = settings["software"]["scala"]
KAFKA_VERSION = settings["software"]["kafka"]

Vagrant.configure("2") do |config|
  config.vm.box = settings["software"]["box"]
  config.vm.box_check_update = true
  (1..NODE_COUNT).each do |i|
    config.vm.define "node#{i}" do |host|
      host.vm.hostname = "node#{i}"
      host.vm.network :private_network, ip: NETWORK + "#{HOST_START+i}"
      host.vm.provider "virtualbox" do |vb|
        vb.cpus = settings["hosts"]["cpu"]
        vb.memory = settings["hosts"]["memory"]
      end

      # if exists, copy staged kafka install from installs folder
      if File.exists?("installs/kafka_#{SCALA_VERSION}-#{KAFKA_VERSION}.tgz")
        host.vm.provision "file", source: "installs/kafka_#{SCALA_VERSION}-#{KAFKA_VERSION}.tgz", destination: "/tmp/kafka_#{SCALA_VERSION}-#{KAFKA_VERSION}.tgz"
      end

      # configure env variables for vms
      host.vm.provision "shell",
        env: {
            "SCALA_VERSION" => SCALA_VERSION,
            "KAFKA_VERSION" => KAFKA_VERSION,
            "NODE_ID" => "#{i}",
            "NODE_COUNT" => NODE_COUNT,
            "NETWORK" => NETWORK,
            "HOST_START" => HOST_START,
            "DOMAIN" => settings["ip"]["domain"],
            "RUN_AS_USER" => settings["configs"]["run_as_user"],
            "INSTALL_FOLDER" => settings["configs"]["install_folder"],
            "LOG_FOLDER" => settings["configs"]["log_folder"],
        },
        path: "scripts/kafka-kraft.sh"
    end
  end
end
