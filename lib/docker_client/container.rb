module DockerClient
  class Container 
    def initialize(connection, container = nil)
      @connection = connection
      @container = container
    end
    
    def create(image, command = nil, options = {})  
      create_parameter = {
        "Image" => image,
        "Cmd" => [],
        "Volumes" => {},
        "VolumesRW" => {},
        "ExposedPorts" => {},
      }
      
      create_parameter["name"] = options["name"] if options["name"] != nil

      if command != nil then
        create_parameter["Cmd"] = command.split(" ") if command.is_a? String
        create_parameter["Cmd"] = command if command.is_a? Array
      end

      volumes = options["volmes"] || []
      volumes.each do |volume|
        volume_from = volume[0]
        volume_to = volume[1] || volume_from
        mode = volume[2] || "rw"
        create_parameter["Volumes"][volume_to] = volume_from
        create_parameter["VolumesRW"][volume_to] = (mode == "rw")
      end
      
      ports = options["ports"] || []
      ports.each do |port|
        host_port = port[0]
        container_port = port[1] || host_port
        protocal = "tcp" #Todo udp ...
        create_parameter["ExposedPorts"]["#{container_port}/#{protocal}"] = {}
      end
      
      begin 
        @container = Docker::Container.create(create_parameter, @connection)
      rescue Excon::Errors::Conflict => ex
        raise Docker::Error::ConflictError, ex.message
      end
    end

    #basic info
    def id
      @container.id
    end

    def inspect
      @container.json
    end
    
    def exist?
      begin
        @container.json
        true
      rescue Docker::Error::NotFoundError
        false
      end
    end

    #function
    def start(options ={})
      start_parameter = {
        "Binds" => [],
        "PortBindings" => {},
      }

      volumes = options["volmes"] || []
      volumes.each do |volume|
        volume_from = volume[0]
        volume_to = volume[1]
        mode = volume[2]
        if mode != nil and mode == "ro" then
          start_parameter["Binds"] << "#{volume_from}:#{volume_to}:ro"
        else
          start_parameter["Binds"] << "#{volume_from}:#{volume_to}"
        end
      end
   
      ports = options["ports"] || []
      ports.each do |port|
        host_port = port[0] #host_port can be empty, then docker assigns a port, but it will change everytime the container restarts
        container_port = port[1] || host_port
        protocal = "tcp" #Todo udp ...
        port_binding = start_parameter["PortBindings"]["#{container_port}/#{protocal}"]
        if start_parameter["PortBindings"]["#{container_port}/#{protocal}"] == nil then
          start_parameter["PortBindings"]["#{container_port}/#{protocal}"] =[]
        end
        start_parameter["PortBindings"]["#{container_port}/#{protocal}"] << {"HostIp" => "","HostPort" => "#{host_port}"}
      end

      start_parameter
      @container.start!(start_parameter)
    end

    def stop
      @container.stop
    end

    def remove(options = {})
      @container.remove(options)
    end

    #running info
    def is_running?
      @container.json["State"]["Running"]
    end

    def exit_code
      @container.json["State"]["ExitCode"]
    end
     
    def logs
      @container.logs(stderr:1, stdout:1, timestamps:1) #follow:1
    end
    
    #network
    def network_settings
      @container.json["NetworkSettings"]
    end
    
    def get_host_network(container_port)
      protocal = "tcp" #Todo udp ...
      (network_settings["Ports"] || {} )["#{container_port}/#{protocal}"] || {}
    end
  end
end
