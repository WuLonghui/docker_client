require "spec_helper"

describe DockerClient::Image do

  let(:connection) do
    docker_server_url = DOCKER_HOST
    connection = Docker::Connection.new(docker_server_url, {})
  end
  
  it "raises error when image already being by another client" do
    threads = [
      Thread.new{DockerClient::Image.new(connection, {"image" => "10.175.100.157:5000/busybox"}).pull},
      Thread.new{DockerClient::Image.new(connection, {"image" => "10.175.100.157:5000/busybox"}).pull}
    ]
    expect {
      threads.each {|t| t.join}
    }.to raise_error(Docker::Error::ImageBeingPulledError)
  end
end
