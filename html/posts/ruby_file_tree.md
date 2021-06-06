# Create a file tree generator using Ruby

This is my first post on this brand new site and in this post I am going to 
discuss how I built this site. This site is composed of only static content i.e.
 there is no backend database or any dynamic activity going on. There are no 
comment features, upvotes, downvotes, claps or any such feature. 

The requirements for my website were simple:
- Show a list of posts (like this one) on the home page (aka write-ups page) where 
visitors could click to read the article
- Show a list of projects (as shown on the projects page) which would take them 
to the corresponding github page when they clicked on it
- Have a contacts page so people interested in contacting me or providing 
feedback could do so

What I didn't want:
- Sorting
- Searching
- Tags

With these requirements, using a webserver like [Django](https://www.djangoproject.com/)
 or [Rails](https://rubyonrails.org/) seemed like an overkill for a site as simple 
as this. So, I turned to static site generators like [Hugo](https://gohugo.io/)
 but it came with a lot of features and a learning curve and time investment that 
I was not willing to make.

So, I decided to write something that would perform the basic required task - 
transfer files to and from the remote server to facilitate easy deployment. For 
that I needed to have a webserver in first place and I chose [Amazon Web
Services](https://aws.amazon.com) due to its generous free tier and having a working knowledge of
several services that it provides.

After signing up I launched a `t2.micro` instance to stay within free tier and chose Ubuntu 20.04
LTS as the OS with an 8 GB SSD storage. I logged in and installed the `apache` webserver and the
certbot agent to generate a free SSL certificate issued by [Let's
Encrypt](https://letsencrypt.org/). 

I will try not to fluff this piece with information that is readily accessible out
there on the Internet and instead I will provide links to external websites where you
can checkout how to perform certain actions like [creating EC2 instance](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EC2_GetStarted.html) or [setting up an apache 
 webserver](https://www.digitalocean.com/community/tutorials/how-to-install-the-apache-web-server-on-ubuntu-20-04) or [generating an SSL certificate from certbot](https://www.digitalocean.com/community/tutorials/how-to-secure-apache-with-let-s-encrypt-on-ubuntu-20-04).

Instead I will start with the configuration changes I performed to get this site up and running. The
first task was [setting up a new user]() with required authorized keys. I am running Ubuntu 20.04 on my
local system as well so the following steps are applicable to an Ubuntu system for setting up of
authorized keys

```
# On local system
# Follow the prompt to create the key (if it doesn't already exist)
ssh-keygen

# Gather the public key
# If private key was stored in a custom location, provide it after hitting enter
ssh-keygen -y

# Get the public key displayed and login to the remote machine
# Check if you have a .ssh folder and authorized_keys file
cat ~/.ssh/authorized_keys

# If it doesn't throw an error, then no need to follow this step
mkdir -p ~/.ssh
touch authorized_keys

# Append your local machine's public key to the authorized_keys file
# Don't miss the >> between the public key and the authorized_keys file path else it will overwrite
the content inside
cp ~/.ssh/auhorized_keys ~/.ssh/authorized_keys.back
echo "<your public key>" >> ~/.ssh/authorized_keys

# Now back on your local machine add the remote machine's public IP address
sudo vim /etc/hosts
# paste the following line after the localhost entry after replacing the values quoted in <> with
actual values.
<remote machine public address> <friendly name>

# Once done, try to ssh to the machine using
ssh <username>@<friendlyname>

# While connecting for the first time it will ask for confirmation whether you trust the remote
system, just type 'yes' and hit enter. 
```

With the authorized keys setup and having established SSH connection with the remote host, now we
need to setup a file transfer mechanism and for that we can use scp `scp /from/path /to/path` but we
want a solution that could integrate well in the overall scheme of things. So I chose to use
[Ruby]() programming language as it provides, besides its clean coding syntax, very nice libraries
(or gems, as they are called) which could prove helpful. Also, I needed something to cut my teeth
on. 

Ruby has a very handy gem called [net-scp](https://github.com/net-ssh/net-scp) which provides all
 the functionalities of the regular scp present on a linux system. The code itself is very simple
and consists of establishing an scp connection and then transferring files

```
files_to_scp = [<An array of files with their relative paths to transfer>]
Net::SCP.start("<friendly remote server name>", "<username>") do |scp|
  files_to_scp.each do |line|
    puts line
    path = line.split
    scp.upload!(path[0], path[1], :recursive => true) do |ch, name, sent, total|
      transfer[name] = "#{sent}/#{total}"
      print "#{name}: #{sent}/#{total}                 "
      STDOUT.goto_column(0)
    end
  end
end
```
