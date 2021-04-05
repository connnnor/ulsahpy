# Making a Python CI/CD Pipeline

My notes as I go through the process of creating a CI/CD Pipeline for a simple Python project. 
I'm following the example described in the _CI/CD In Practice_ section from the [Unix and Linux System Administrator's Handbook](https://www.admin.com) however I used Python for my application and AWS as my Cloud provider instead of Go and DigitalOcean as described in the text.

This example includes the following elements

* A trivial web application `ulsahpy` 
* Unit tests for the application
* An AMI containing the application and its dependencies
* A single server testing environment
* __TODO__ A load balanced "production" environment 
* A CI/CD pipeline to tie everything together

And uses the following tools and services:

* AWS EC2 instances and load balancers
* HashiCorp's Packer for provisioning EC2 images
* HashiCorp's Terraform to create deployment environments
* Jenkins to manage the CI/CD pipeline

## Step 0: Setup Dev Environment

Install development dependencies and add to path

```
$ sudo apt update && sudo apt -y upgrade
$ sudo apt -y install python3-pip python3-venv
$ python3 -m pip install virtualenv
$ echo 'export PATH=$PATH:$HOME/.local/bin'  >> ~/.bashrc
```

Create a directory for our project (`ulsahpy`), create and activate a virtual env:

```
$ mkdir ulsahpy && cd ulsahpy
$ virtualenv venv
$ source venv/bin/activate
```

Install dependencies for our python code: `flask` for our web framework then freeze the current state.

```
$ pip install flask
$ pip freeze > requirements.txt
```

Later, when the environment needs to be recreated on test or production systems, running the following command will install the same packages:

```
$ pip install -r requirements.txt
```

## Step 1: Write a Simple Application

The example application is a web service with a single feature. It returns, as JSON, the authors associated with a specified edition of the Unix and Linux System Administrator's Handbook. For example, the following query shows the authors for the 4th edition:

```
$ curl localhost/?edition=4
{
  "authors": [
    "Evi",
    "Garth",
    "Trent",
    "Ben"
  ],
  "number": 4
}
```

If a user tries to request unavailable editions, an error message is returned, like:

```
[con ~ 0] > curl -s 'http://127.0.0.1:8081/?edition=9'
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 3.2 Final//EN">
<title>404 Not Found</title>
<h1>Not Found</h1>
<p>9th edition is invalid</p>
```

There is also a health check endpoint:

```
$ curl localhost/healthy
{
    "healthy" : "true"
}
```

Here's what the directory tree looks like at this point:

```
(venv) ubuntu@ip-172-31-63-50:~/ulsahpy$ tree -I __pycache__ --matchdirs
.
├── requirements.txt
├── ulsahpy
│   ├── __init__.py
│   ├── authors.json
│   └── ulsahpy.py
└── venv
    ├── bin
 ## output truncated
```

## Step 2: Write some unit tests

We'll create some unit tests using the python `unittest` module to test the `ordinal` function. This function takes an integer and determines the corresponding ordinal expression(e.g. `ordinal(1)="1st"`, `ordinal(2)="2nd"`, etc.)

Directory tree now:

```
(venv) ubuntu@ip-172-31-63-50:~/ulsahpy$ tree -I __pycache__ --matchdirs
.
├── requirements.txt
├── ulsahpy
│   ├── __init__.py
│   ├── authors.json
│   ├── test
│   │   ├── __init__.py
│   │   └── test_ulsahpy.py
│   └── ulsahpy.py
└── venv
    ├── bin
 ## output truncated
```

Run the test by executing python's `unittest` module:

```
(venv) ubuntu@ip-172-31-63-50:~/ulsahpy$ python -m unittest
....
----------------------------------------------------------------------
Ran 4 tests in 0.001s

OK
```

## Step 3: Configure Jenkins Pipeline

__Install__:

First ... Jenkins needs to be installed along with some dependencies. 

```
sudo apt-get -y install openjdk-8-jdk
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb https://pkg.jenkins.io/debian-stable binary/ > \
    /etc/apt/sources.list.d/jenkins.list'
sudo apt-get update
sudo apt-get -y install jenkins
```

Now complete the Jenkins setup by visiting `<your-jenkins-host:8080>` in your browser and following the instructions. More detailed instructions available [here](https://aws.amazon.com/blogs/devops/setting-up-a-ci-cd-pipeline-by-integrating-jenkins-with-aws-codebuild-and-aws-codedeploy/)

We'll also need HashiCorp's `Packer` and `Terraform`, so install them like so (more detailed instructions [here](https://learn.hashicorp.com/tutorials/packer/getting-started-install)):

```
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
sudo apt-get update && sudo apt-get -y install packer terraform
```

__Config__:

Configure the project in Jenkins using the GUI. Here are the steps I followed:

* Navigate to your Jenkins dashboard in your web browser
* Click `Dashboard -> New Item`
* Give it a name and select a pipeline project
* In _Build Triggers_ section:
    * Select _Poll SCM_ and use the schedule `H/5 * * * *` to poll every 5 minutes
* In _Pipeline_ Section:
    * For _Definition_ select _Pipeline Script from SCM_ 
    * In _SCM_ Section (source: [jenkins-git-err-stackoverflow]
        * Enter the information for your git repo URL and credentials
        * Click _advanced_ and set _Name_ to `origin` and _Refspec_ to `+refs/pull/*:refs/remotes/origin/pr/*`
        * Leave _Branches to build_ empty
        * In _Additional Behaviours_ add `Clean Before Checkout`
    * Set _Script Path_ to `pipeline/Jenkinsfile`
    * Disable _Lightweight Checkout_
* Save it

Now Jenkins will poll for changes every 5 minutes and execute the pipeline described in `Jenkinsfile` whenever a new commit is pushed.

__Jenkinsfile__:

Since this is a small project, I've combined the CI/CD and application code in the same repository. All CI/CD code is kept in the `pipeline` subdirectory. 

First, let's create a Jenkinsfile that only checks out our source code:

```
pipeline {
  agent any
  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }
  }
}
```

Now add steps to install our dependencies and run unit tests:

```
pipeline {
  agent any
  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }
    stage('Build') {
      steps {
        sh '''#!/bin/bash -l
        python3 -m venv venv
        . venv/bin/activate
        pip install -r requirements.txt
        '''
      }
    }
    stage('Unit Test') {
      steps {
        sh '''#!/bin/bash -l
        . venv/bin/activate
        python3 -m unittest
        '''
      }
    }
  }
}
```

## Step 4: Building an AMI for testing

Once this section is complete, Jenkins will spin up a new EC2 instance, install our dependencies, then take a snapshot of that instance and create an AMI that can be used to spin up new EC2 instances

__NOTE__: You'll need to have credentials set up using one of the methods described [here](https://www.packer.io/docs/builders/amazon#specifying-amazon-credentials).
I created an IAM Role following the directions they specified in _IAM Task or Instance Role_, then attached it to the EC2 instance I'm running Jenkins on (EC2 -> Actions -> Security -> Modify IAM Role)

Create a new directory `packer` inside the existing `pipeline` directory and add the three files shown below (`provisioner.sh`, `ulsahpy.hcl`, and `ulsahpy.service`):


`provisioner.sh`:
```
#!/usr/bin/env bash 
app=ulsahpy

# Update OS and install python deps
sudo apt-get update && sudo apt-get -y upgrade
sudo apt-get -y install python3-pip python3-venv
# make sure virtualenv is in path
PATH=$PATH:$HOME/.local/bin
# add a user and create home dir
#sudo /usr/sbin/useradd -m -s /usr/sbin/nologin $app

# Set up the working directory and app
mkdir -p "$HOME"/"$app"
cp -R /tmp/"$app" "$HOME"/"$app"
cp /tmp/requirements.txt "$HOME"/"$app"
# Create virtualenv and install app deps
cd $HOME/"$app"
python3 -m venv venv
. venv/bin/activate
pip install -r requirements.txt

# Enable the systemd unit 
sudo cp /tmp/"$app".service /etc/systemd/system/
sudo systemctl enable $app
```


`ulsahpy.service`:
```
[Unit]
Description=ulsahpy HTTP Demo Service (running on port 8081)

[Service]
# Command to execute when the service is started
ExecStart=/home/ubuntu/ulsahpy/venv/bin/python /home/ubuntu/ulsahpy/ulsahpy/ulsahpy.py

[Install]
WantedBy=multi-user.target
```

`ulsahpy.pkr.hcl`:
```
variable "timestamp" {
  type    = string
  default = "{{isotime \"2006-01-02 03:04:05\"}}"
}

locals { timestamp = regex_replace(timestamp(), "[- TZ:]", "") }

variable "region" {
  type    = string
  default = "us-east-1"
}

source "amazon-ebs" "ulsahpy-AWS" {
  ami_name      = "ulsahpy-${local.timestamp}"
  instance_type = "t2.micro"
  region        = "${var.region}"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/*ubuntu-focal-20.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username  = "ubuntu"
}

build {
  sources = ["source.amazon-ebs.ulsahpy-AWS"]

  provisioner "file" {
    destination = "/tmp"
    source      = "ulsahpy"
  }

  provisioner "file" {
    destination = "/tmp/requirements.txt"
    source      = "requirements.txt"
  }

  provisioner "file" {
    destination = "/tmp/ulsahpy.service"
    source      = "pipeline/packer/ulsahpy.service"
  }

  # wait for cloud-init to complete before running apt-get
  provisioner "shell" {
    inline = ["/usr/bin/cloud-init status --wait"]
  }

  provisioner "shell" {
    script = "pipeline/packer/provisioner.sh"
  }
}
```

I added the provisioner to wait for `cloud-init` after running into intermittent `apt-get` errors during the Packer build. It seems that the error occurs because `cloud-init` is still configuring the instance while `apt-get` runs. (Source: [cloud-init-apt-get-error])

At the end of the Jenkinsfile, add a build image step:

```
...
    stage('Build Image') {
      steps {
        sh 'packer build pipeline/packer/ulsahpy.pkr.hcl > packer.txt'
        sh 'awk \'/AMIs were created:/{getline;print;}\' packer.txt | grep -E -o \'ami-[0-9a-z]{17}\' > aws_image.txt'
      }
    }
...
```

That creates an image using packer, writes the output to a file, then parses the output file `packer.txt` and writes the AMI ID to `aws_image.txt`

## Step 5: Provisioning a test system

Now we're ready to create an EC2 instance to run tests on as part of our pipeline. This step uses Terraform to deploy the AMI created in the previous step to a new EC2 instance, and attaches a new security group containing some rules needed to test the application.

Create a new directory `testing` inside the existing `pipeline` directory and add the two files shown below (`tf_testing.sh`, and `ulsahpy.tf`):

`tf_testing.sh`:
```
cp aws_image.txt pipeline/testing 
cd pipeline/testing
terraform init
terraform apply \
  -var aws_image="$(<aws_image.txt)" \
  -auto-approve \
  -no-color
terraform output -raw ulsahpy-test-ip > ../../ec2_ip.txt
```

`ulsahpy.tf`:
```
variable "aws_image" {}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

provider "aws" {
  region  = "us-east-1"
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_security_group" "ulsahpy_test" {
  name        = "ulsahpy_test"
  description = "Allow ICMP ping, and HTTP for application"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "ICMP for pinging"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Flask Port"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ulsahpy-test-sg"
  }
}

resource "aws_instance" "ulsahpy-latest" {
  ami           = var.aws_image
  instance_type = "t2.micro"
  key_name      = "TestKP"
  vpc_security_group_ids = [aws_security_group.ulsahpy_test.id]

  tags = {
    Name = "ulsahpy-test"
  }
}

output "ulsahpy-test-ip" {
  value = aws_instance.ulsahpy-latest.public_ip
}
```

For troubleshooting I just manually ran the `terraform apply` and `terraform destroy` commands to make sure everything worked before I added it into my pipeline

Terraform outputs the public IP address of the instance, so to test everything sort of works, I pointed my browser to `<that-ip-address>:8081/healthy` and verified the output was the JSON healthy message.


Now, add another step at the end of the Jenkinsfile to run this as part of our pipeline:

```
...
    stage('Create Instance') {
      steps {
        sh 'bash pipeline/testing/tf_testing.sh'
      }
    }
...
```

__Note__: So far our pipeline only runs `terraform apply` without `terraform destroy` so any instances created by the pipeline need to be manually cleaned up

## Step 6: Testing our Instance

Now that a test instance is spun up as part of the pipeline, we can run automated tests on it. 

First, `ping` the instance to verify it's actually alive then We'll use `curl` to query the IP address of our test instance on the port our application listens on (8081) and check the response with `grep`. 

Now, add another step at the end of the Jenkinsfile to run the new tests:

```
...
    stage('Test and destroy the instance') {
      steps {
        sh '''#!/bin/bash -l
        curl --fail \$(<ec2_ip.txt):8081/healthy
        curl -D - -v \$(<ec2_ip.txt):8081/?edition=5 | grep "HTTP/1.1 200" 
        curl -D - -v \$(<ec2_ip.txt):8081/?edition=6 | grep "HTTP/1.1 404"
        cd pipeline/testing
        terraform destroy -var aws_image=\$(<aws_image.txt) -auto-approve
        '''
      }
    }
...
```

Looking in the console output in Jenkins I can see a couple lines that (somewhat vaguely) show my tests are working:

```
> GET /?edition=5 HTTP/1.1
> Host: 54.166.95.146:8081
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
* HTTP 1.0, assume close after body
< HTTP/1.0 200 OK
< Content-Type: application/json
< Content-Length: 60
< Server: Werkzeug/1.0.1 Python/3.8.5
< Date: Mon, 05 Apr 2021 20:49:13 GMT
< 
{ [60 bytes data]
```

```
> GET /?edition=6 HTTP/1.1
> Host: 54.166.95.146:8081
> User-Agent: curl/7.68.0
> Accept: */*
> 
* Mark bundle as not supporting multiuse
* HTTP 1.0, assume close after body
< HTTP/1.0 404 NOT FOUND
```

## Step 7: Deploying to multiple instances and Load Balancer

The last step is deploying our application to a (mock) production environment as part of the pipeline. The production environment in this case is made up of two EC2 instances and an application load balancer. 
We'll use Terraform again for this step.

__TODO TODO TODO TODO__

## References:

* [Continuous Integration With Python: An Introduction](https://realpython.com/python-continuous-integration/)
* [Lower Level Virtualenv](https://python-guide.readthedocs.io/en/latest/dev/virtualenvs/#lower-level-virtualenv)
* [Installing - Jenkins Linux](https://www.jenkins.io/doc/book/installing/linux/)
* [Packer - Build an Image](https://learn.hashicorp.com/tutorials/packer/getting-started-build-image?in=packer/getting-started)

[jenkins-git-err-stackoverflow]: https://stackoverflow.com/questions/23906352/git-pullrequest-job-failed-couldnt-find-any-revision-to-build-verify-the-repo/39072182#39072182
[cloud-init-apt-get-error]: https://serverfault.com/questions/904080/inconsistent-apt-get-update-behaviour-on-official-ubuntu-aws-ami
