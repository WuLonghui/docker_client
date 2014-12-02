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

    def create(image, command = nil, options = {})
      ports = options["-p"] || options["--publish"]
      volumes = options["-v"] || options["--volume"]
      
      container = Container.new(@connection, image, command, "volmes" => volumes, "ports" => ports)
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

    def rm_all
      ps("-a").each do |container|
        container.remove("force" => true)
      end
    end
  end
end
