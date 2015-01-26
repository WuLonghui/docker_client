
module DockerClient
  class Image 
  
    IMAGE_PULL_POLICY_PULL_ALWAYS = "pull_always"
    IMAGE_PULL_POLICY_PULL_NEVER = "pull_never"
    IMAGE_PULL_POLICY_PULL_IF_NOT_PRESENT = "pull_if_not_present"
    
    def initialize(connection, options)
      @connection = connection
      @image = options["image"]
      @pull_policy = options["pull_policy"] || IMAGE_PULL_POLICY_PULL_NEVER
    end
    
    def to_s
      @image
    end
    
    def pull
      body = @connection.post('/images/create', {'fromImage' => @image})
      json = Docker::Util.fix_json(body)
     
      if json.size >= 2 and json[1]["error"] =~/not found/
        raise Docker::Error::ImageNotFoundError, json[1]["error"]   
      elsif json[0]["status"] =~ /already being pulled by another client/
        raise Docker::Error::ImageBeingPulledError, json[0]["status"]
      end
    end
    
    def pull_by_policy
       return if @image.nil?
       case @pull_policy
       when IMAGE_PULL_POLICY_PULL_NEVER 
         raise Docker::Error::ImageNotPresentError, "#{@image} isn't present" unless Docker::Image.exist?(@image, {}, @connection)
       when IMAGE_PULL_POLICY_PULL_ALWAYS
         pull
       when IMAGE_PULL_POLICY_PULL_IF_NOT_PRESENT
         pull unless Docker::Image.exist?(@image, {}, @connection)
       end
     end
    
  end
end
