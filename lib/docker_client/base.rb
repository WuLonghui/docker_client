module DockerClient
  def self.create(server_url, options = {})
    Base.new(server_url, options)
  end

  class Base
    def initialize(server_url, options)
      @server_url = server_url
      @connection = Docker::Connection.new(server_url, options)
      validate_version!
    end

    def validate_version!
      Docker.info(@connection)
    rescue Docker::Error::DockerError
      raise Docker::Error::VersionError, "Expected API Version: #{Docker::API_VERSION}"
    end
    
    def server_url
      @server_url
    end

    def connection
      @connection
    end
    
    def container(id_or_name)
      Container.new(@connection, "id_or_name" => id_or_name)
    end

    def info
      Docker.info(@connection)
    end
    
    def version
      Docker.version(@connection)
    end
    
    def create(image, command = nil, options = {})
      name = options["--name"]
      workdir = options["-w"] || options["--workdir"]
      ports = options["-p"] || options["--publish"]
      volumes = options["-v"] || options["--volume"]
      envs = options["-e"] || options["--env"]
     
      container = Container.new(@connection, "image" => image, "command" => command, "name" => name, "workdir" => workdir, "volmes" => volumes, "ports" => ports, "envs" => envs)
      container.create
      container  
    end

    def run(image, command = nil, options = {})
      container = create(image, command, options)
      container.start
      container
    end

    def ps(*options)
      all = options.include?("-a") || options.include?("-all") 
      Docker::Container.all({"all"=>all}, @connection)
    end

    def rm(id_or_name, *options)
      force = options.include?("-f") || options.include?("--force") 
      container = Docker::Container.get(id_or_name, {}, @connection)
      container.remove("force" => force)
    end

    def rm_all
      ps("-a").each do |container|
        container.remove("force" => true)
      end
    end
    
    def port(id_or_name, port = nil)
      container = self.container(id_or_name)
      unless port.nil? then
        return container.get_host_network(port)
      end
      network_settings = container.get_port_mapping
    end
    
  end
end
