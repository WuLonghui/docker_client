module DockerClient
  def self.create(server_url, options = {})
    Base.new(server_url, options)
  end

  class Base
    def initialize(server_url, options)
      @server_url = server_url
      @connection = Docker::Connection.new(server_url, options)
    end

    def server_url
      @server_url
    end

    def connection
      @connection
    end
    
    def container(id_or_name)
      Container.new(@connection, id_or_name)
    end

    def create(image, command = nil, options = {})
      name = options["--name"]
      ports = options["-p"] || options["--publish"]
      volumes = options["-v"] || options["--volume"]
      
      container = Container.new(@connection)
      container.create(image, command, "name" => name, "volmes" => volumes, "ports" => ports)
      container  
    end

    def run(image, command = nil, options = {})
      ports = options["-p"] || options["--publish"]
      volumes = options["-v"] || options["--volume"]

      container = create(image, command, options)
      container.start("volmes" => volumes, "ports" => ports)
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
  end
end
