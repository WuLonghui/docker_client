require "spec_helper"

describe DockerClient do

  let(:docker_client) do
    docker_server_url = DOCKER_HOST
    docker_client = DockerClient.create(docker_server_url)
  end
  
  after(:all) do
    docker_server_url = DOCKER_HOST
    docker_client = DockerClient.create(docker_server_url)
    docker_client.rm_all unless ENV["DEBUG"]
  end
  
  it "shows info and version" do
    expect(docker_client.info).to_not be_nil
    expect(docker_client.version).to_not be_nil
  end
    
  it "creates a client" do
    expect(docker_client.server_url).to eq(DOCKER_HOST)
    expect(docker_client.connection).to_not be_nil 
  end
  
  it "creates a container" do
    container = docker_client.create("trusty", "ls")
    expect(container.id).to_not be_nil 
  end
    
  it "shows all container" do  
    docker_client.rm_all
    3.times {docker_client.create("trusty", "ls") }
    expect(docker_client.ps("-a").size).to eq(3)
  end
  
  it "runs a container" do
    container = docker_client.run("trusty", "whoami")
    expect(container.id).to_not be_nil 
    
    while container.is_running? do
      sleep 0.1
    end
    expect(container.exit_code).to eq(0)
    expect(container.logs).to include("root")
  end

  it "stops a container" do
    container = docker_client.run("trusty", ["/bin/sh", "-c", "while true; do echo hello world; sleep 1; done"])
    sleep 2
    expect(container.logs).to include("hello world")
    expect(container.is_running?).to be true

    container.stop
    expect(container.is_running?).to be false
  end

  it "restarts a container" do
    volumes = [
     ["/home", "/home", "ro"],
    ]
    
    ports = [
      [49159, 8080],
    ]
    container = docker_client.run("trusty", ["/bin/sh", "-c", "while true; do echo hello world; sleep 1; done"], "-p" => ports, "-v" => volumes) 
    expect(container.is_running?).to be true

    before_inspect = container.inspect
    container.stop
    expect(container.is_running?).to be false
    
    container.start

    after_inspect = container.inspect
    before_inspect.delete("NetworkSettings")
    after_inspect.delete("NetworkSettings")
    before_inspect.delete("State")
    after_inspect.delete("State")
    expect(container.is_running?).to be true
    expect(before_inspect).to eq after_inspect
  end
  
  it "starts the same container" do
    volumes = [
     ["/home", "/home", "ro"],
    ]
    
    ports = [
      [49160, 8080],
    ]
    container1 = docker_client.run("trusty", ["/bin/sh", "-c", "while true; do echo hello world; sleep 1; done"], "-p" => ports, "-v" => volumes) 
    expect(container1.is_running?).to be true

    before_inspect = container1.inspect
    container1.stop
    expect(container1.is_running?).to be false
    
    container2 = docker_client.container(container1.id)
    container2.start

    after_inspect = container2.inspect
    before_inspect.delete("NetworkSettings")
    after_inspect.delete("NetworkSettings")
    before_inspect.delete("State")
    after_inspect.delete("State")
    expect(container2.is_running?).to be true
    expect(before_inspect).to eq after_inspect  
  end
  
  it "removes a container" do
    container = docker_client.run("trusty", "whoami")
    expect(container.id).to_not be_nil 
    
    while container.is_running? do
      sleep 0.1
    end
    expect(container.exit_code).to eq(0)
    expect(container.logs).to include("root")
    
    expect(container.exist?).to be true
    container.remove
    expect(container.exist?).to be false
  end

  it "removes a container by name" do
    container = docker_client.run("trusty", ["/bin/sh", "-c", "while true; do echo hello world; sleep 1; done"], "--name" => "tracy")
    expect(container.is_running?).to be true 

    docker_client.rm("tracy", "-f")   
    expect(container.exist?).to be false
  end
  
  it "removes a container with force" do
    container = docker_client.run("trusty", ["/bin/sh", "-c", "while true; do echo hello world; sleep 1; done"])
    expect(container.is_running?).to be true  

    container.remove("force" => true)
    expect(container.exist?).to be false
  end
  
  it "mounts vloumes to a container" do
    dir1 = File.join(File.dirname(__FILE__), '..', 'fixtures', 'volume', "1")
    dir2 = File.join(File.dirname(__FILE__), '..', 'fixtures', 'volume', "2")
    volumes = [
     [dir1, "/home"],
     [dir2, "/tmp"],
    ]

    container = docker_client.run("trusty", "ls /home /tmp", "-v" => volumes)
    expect(container.id).to_not be_nil 
    
    while container.is_running? do
      sleep 0.1
    end
    expect(container.exit_code).to eq(0)
    expect(container.logs).to include("test1")
    expect(container.logs).to include("test2")
  end
  
  it "fails to write to read only vloume" do
    dir1 = File.join(File.dirname(__FILE__), '..', 'fixtures', 'volume', "1")
    volumes = [
     [dir1, "/home", "ro"],
    ]

    container = docker_client.run("trusty", "touch /home/do", "-v" => volumes)
    expect(container.id).to_not be_nil 
    
    while container.is_running? do
      sleep 0.1
    end
    expect(container.exit_code).not_to eq(0)
    expect(container.logs).to include("Read-only file system")
  end
  
  it "publishs ports for a container" do
    expect(system("lsof -i:49153|grep docker")).to be(false)
    expect(system("lsof -i:49154|grep docker")).to be(false)
    ports = [
      [49153],
      [49154, 8080],
      [49155, 8080],
      ["", 80], 
    ]
    container = docker_client.run("trusty", ["/bin/sh", "-c", "while true; do echo hello world; sleep 1; done"], "-p" => ports)  
    expect(container.is_running?).to be(true)
    expect(system("lsof -i:49153|grep docker > /dev/null 2>&1")).to be(true)
    expect(system("lsof -i:49154|grep docker > /dev/null 2>&1")).to be(true)
    expect(system("lsof -i:49155|grep docker > /dev/null 2>&1")).to be(true)    

    #check port mapping
    expect(container.get_host_network(49153).first["HostPort"].to_i).to be(49153)
    expect(container.get_host_network(8080)[0]["HostPort"].to_i).to be(49154)
    expect(container.get_host_network(8080)[1]["HostPort"].to_i).to be(49155)
    container.stop
  end
  
  it "raises error when create container with existed name" do
    container1 = docker_client.run("trusty", "ls", "--name" => "json")
    expect(container1.id).to_not be_nil 

    expect { 
      docker_client.run("trusty", "ls", "--name" => "json")
    }.to raise_error(Docker::Error::ConflictError)
  end
  
  it "fetchs a container by name" do
    docker_client.run("trusty", "ls", "--name" => "toby")
   
    container = docker_client.container("toby")
    expect(container.name).to eq("toby")
    expect(container.exist?).to be(true)
  end

  it "fetchs a container by id" do
    id = docker_client.run("trusty", "ls", "--name" => "may").id
   
    container = docker_client.container(id)
    expect(container.id).to eq(id)
    expect(container.name).to eq("may")
    expect(container.exist?).to be(true)
  end
  
  it "fetchs a inexist container" do
    container = docker_client.container("kk")
    expect(container.id).to be_nil
    expect(container.exist?).to be(false)
  end
  
  it "lists port mappings for the container" do
    ports = [
      [49171],
      [49172, 8080],
      [49173, 8080],
      [49174, 80], 
    ]
    container = docker_client.run("trusty", ["/bin/sh", "-c", "while true; do echo hello world; sleep 1; done"], "-p" => ports)  
    expect(container.is_running?).to be(true)
    
    expect(docker_client.port(container.id, 8080)).to eq([{"HostIp"=>"0.0.0.0", "HostPort"=>"49172"}, {"HostIp"=>"0.0.0.0", "HostPort"=>"49173"}])
    expect(docker_client.port(container.id)).to eq({"49171/tcp"=>[{"HostIp"=>"0.0.0.0", "HostPort"=>"49171"}], "80/tcp"=>[{"HostIp"=>"0.0.0.0", "HostPort"=>"49174"}], "8080/tcp"=>[{"HostIp"=>"0.0.0.0", "HostPort"=>"49172"}, {"HostIp"=>"0.0.0.0", "HostPort"=>"49173"}]})
  end
  
  it "sets envs for a container" do
    envs = {"workspace" => "/home/do"}
    container = docker_client.run("trusty", "env", "-e" => envs)
        while container.is_running? do
      sleep 0.1
    end
    expect(container.logs).to include("workspace=/home/do")
  end
  
  it "streams logs for a container" do
    container = docker_client.run("trusty", ["/bin/sh", "-c", "for i in 1 2 3 ; do echo hello world; sleep 1; done"])
    logs = []
    container.streaming_logs do |stream, chunk|
      logs << "#{stream}:#{chunk}"
    end
    expect(logs.size).to eq 3
  end
  
  it "sets workdir for a container" do
    container = docker_client.run("trusty", "pwd", "-w" => "/var")
    expect(container.id).to_not be_nil 
    
    while container.is_running? do
      sleep 0.1
    end
    expect(container.exit_code).to eq(0)
    expect(container.logs).to include("/var")
  end
end
