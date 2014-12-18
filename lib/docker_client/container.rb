module DockerClient
  class Container 
    def initialize(connection, options = {})
      @connection = connection
      
      @image = options["image"]
      @command = options["command"]
      @name = options["name"]
      @volumes = options["volmes"] || []
      @ports = options["ports"] || []
      @envs = options["envs"] || {}

      @id_or_name = options["id"] || options["name"] || options["id_or_name"]
      @container = nil
      if @id_or_name!= nil then
        @container = Docker::Container.get(@id_or_name, {}, @connection)
      end
      
      #if container not found, container=nil
      rescue Docker::Error::NotFoundError
    end
    
    def create
      create_parameter = {
        "Image" => @image,
      }
      
      unless @name.nil? then
        create_parameter["name"] = @name if @name != nil
      end
      
      unless @command.nil? then
        create_parameter["Cmd"] = @command.split(" ") if @command.is_a? String
        create_parameter["Cmd"] = @command if @command.is_a? Array
      end

      unless @volumes.empty? then
        create_parameter["Volumes"] = {}
        create_parameter["VolumesRW"] = {}
        @volumes.each do |volume|
          volume_from = volume[0]
          volume_to = volume[1] || volume_from
          mode = volume[2] || "rw"
          create_parameter["Volumes"][volume_to] = volume_from
          create_parameter["VolumesRW"][volume_to] = (mode == "rw")
        end
      end
      
      unless @ports.empty? then
        create_parameter["ExposedPorts"] = {}
        @ports.each do |port|
          host_port = port[0]
          container_port = port[1] || host_port
          protocal = "tcp" #Todo udp ...
          create_parameter["ExposedPorts"]["#{container_port}/#{protocal}"] = {}
        end
      end
      
      unless @envs.empty? then
        create_parameter["Env"] = []
        @envs.each do |key, value|
          create_parameter["Env"] << "#{key}=#{value}"
        end
      end
      
      begin 
        @container = Docker::Container.create(create_parameter, @connection)
      rescue Excon::Errors::Conflict => ex
        raise Docker::Error::ConflictError, ex.message
      end
    end

    #basic info
    def id
      if @id == nil and @container != nil then
        @id = @container.id
      end
      @id
    end

    def name
      if @name == nil and @container != nil then
        @name = @container.json["Name"].slice(1, @container.json["Name"].length)
      end
      @name
    end
    
    def inspect
      return {} if @container == nil
      @container.json
    end
    
    def exist?
      return false if @container == nil
      begin
        @container.json
        true
      rescue Docker::Error::NotFoundError
        false
      end
    end

    #function
    def start
      start_parameter = {}
      
      unless @volumes.empty? then
        start_parameter["Binds"] = []  
        @volumes.each do |volume|
          volume_from = volume[0]
          volume_to = volume[1]
          mode = volume[2]
          if mode != nil and mode == "ro" then
            start_parameter["Binds"] << "#{volume_from}:#{volume_to}:ro"
          else
            start_parameter["Binds"] << "#{volume_from}:#{volume_to}"
          end
        end
      end
   
      unless @ports.empty? then
        start_parameter["PortBindings"] = {} 
        @ports.each do |port|
          host_port = port[0] #host_port can be empty, then docker assigns a port, but it will change everytime the container restarts
          container_port = port[1] || host_port
          protocal = "tcp" #Todo udp ...
          port_binding = start_parameter["PortBindings"]["#{container_port}/#{protocal}"]
          if start_parameter["PortBindings"]["#{container_port}/#{protocal}"] == nil then
            start_parameter["PortBindings"]["#{container_port}/#{protocal}"] =[]
          end
          start_parameter["PortBindings"]["#{container_port}/#{protocal}"] << {"HostIp" => "","HostPort" => "#{host_port}"}
        end
      end
      
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
    
    #dynamic network
    def network_settings
      @container.json["NetworkSettings"] || {}
    end
    
    def get_port_mapping
      (network_settings["Ports"] || {} )
    end
    
    def get_host_network(container_port)
      protocal = "tcp" #Todo udp ...
      (network_settings["Ports"] || {} )["#{container_port}/#{protocal}"] || {}
    end
    
    #static network
    def exposed_ports
      (@container.json["Config"] || {})["ExposedPorts"]
    end
    
    def port_bindings
      (@container.json["HostConfig"] || {})["PortBindings"]
    end
  end
end
