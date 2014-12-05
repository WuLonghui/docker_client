# This module extends the Errors for the docker api gem.
module Docker::Error

  # Raised when Conflict.
  class ConflictError < DockerError; end

end
