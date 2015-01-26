# This module extends the Errors for the docker api gem.
module Docker::Error

  # Raised when Conflict.
  class ConflictError < DockerError; end

  # Raised when image isn't present on disk, container will fail if the image isn't present
  class ImageNotPresentError < DockerError; end
  
  # Raised when fail to pull image
  class ImagePullError < DockerError; end
  
  # Raised when image not found on docker registry
  class ImageNotFoundError < DockerError; end
  
  # Raised when image already being pulled by another client
  class ImageBeingPulledError < DockerError; end
end
