# Processing form inputs using CGI scripts

While building this blog, I had to be able to store the messages that visitors 
decided to send me. So, I decided to use [CGI](https://httpd.apache.org/docs/current/howto/cgi.html) scripts to process the form data and 
store the messages in [dynamo db]() (for free, thanks to AWS's free tier offering).

## Setting up CGI on Apache webserver running on Ubuntu 20.04
You can get started with [setting up Apache to run CGI script](https://httpd.apache.org/docs/current/howto/cgi.html) by following the link and here I am presenting the steps that I had to follow 
(including and in addition to the ones mentioned in the documentation) for my 
future self (and, for you, the reader).

1. Goto the directory where your site specific configuration files are present. 
In my case it is in the `/etc/apache2/sites-enabled/` directory
2. Edit the configuration file and add the following lines to the configuration file. 
In my case, I had two conf files - one for port 80 and another for 443. I am
 making changes to the configuration file with the virtual host for port 443.

```
LoadModule cgid_module /usr/lib/apache2/modules/mod_cgid.so
LoadModule request_module /usr/lib/apache2/modules/mod_request.so
ScriptSock "/var/www/a93_in/cgid.sock"
```

  - The first line loads the [cgid_module](https://httpd.apache.org/docs/2.4/mod/mod_cgid.html) 
to enable the CGI feature. The path to the shared object may be different on 
your machine. You can get a hint about the path by running `apachectl -V` and 
check the paths present in the output. You may also need to run `a2enmod cgid` 
if your apache services fails to restart complaining about missing modules. 
There is a [cgi_module](https://httpd.apache.org/docs/2.4/mod/mod_cgi.html) as 
well that you may want to look into. The basic difference is that the cgid module 
talks to an external cgi daemon and is compatible with threaded Unix MPMs (which is 
applicable in my case) 
available as well
  - The second line loads the [request module](https://httpd.apache.org/docs/trunk/mod/mod_request.html) 
which allows us to retain the body of the request, which, apparently, is 
discarded when serving static sites. We will not be using its features up front but 
it may come in handy later on.
  - The third line sets up the socket file prefix. This socket file is used to 
communicate with the cgi daemon. I didn't set it up initially and the error log 
mentioned *unable to connect to cgi daemon after multiple tries*. See this
 answer on [ServerFault](https://serverfault.com/questions/142801/13-permission-denied-on-apache-cgi-attempt)

3. In the same file, add the following line within the VirtualHost definition

```
ScriptAlias "/cgi-bin/" "/var/www/a93_in/cgi-bin/"
```

4. Run the following commands to enable the modules (if not already enabled)

```
a2enmod cgid

a2enmod request
```

5. Restart the apache service

```
sudo systemctl restart apache2
```

## Creating CGI script to parse the data
CGI scripts can be written in any language as long as there are provisions to run 
the scripts on our machine. I have written the scripts in [Ruby](https://www.ruby-lang.org/en/).
 If it is not already installed on your machine, you can follow the [instructions here](https://www.ruby-lang.org/en/documentation/installation/)

We will start with creating a simple script that reads the url encoded request 
body, decodes it, changes it to a hash and stores it in a JSON document and sends 
a 'Hello, World' response back

```
require 'uri'
require 'json'

File.open(Time.now, File::CREAT | File::WRONLY, 0666) do |fh| 
  JSON.dump(URI.decode_www_form(gets.chomp).to_h, fh)
end  

puts "Content-Type text/html\n\n"
puts "Hello, World!"
```

Let's start going through the line by line. The first two statements are require 
statements to make the facilities [URI]() and [JSON]() classes available to our script. 
In the next line we [open a file]() in [write-only mode]() (and [creating it]() if it doesn't 
already exist) and then we [set its permission]() to 0666 allowing everybody to read 
and write to this file. The name of the file is set to the time at which the script 
runs using [`Time.now`]() (it is not a good practice to use this method as it becomes unreliable with 
increasing load. But it suffices for the current example). In the next line we are 
reading the request body from the STDIN using `gets.chomp` (see this [StackOverflow 
answer]()) and then we [decode it]() 
from the [url encoded form]() using `URI.decode_www_form` and we [convert it to a dictionary]() 
using `to_h` method. Once that is done, we are using the `JSON.dump` method to 
[dump the contents]() of the hash to the open file handle in the JSON format. The nice thing 
about using this format is that we don't have to close the file explicitly and it is 
automatically closed.

In the next two statements we are returning an HTTP response by printing it to the 
STDOUT. This response will be sent back to the browser and rendered as 'Hello, World`

## Sending a "Hello, World!" message

In order to test this thing I set up a simple HTML5 form with two fields which represented 
my requirements in terms of a contact form - an optional email box so that I 
could reply to the person if they wanted me to and a required message box. This is 
what the HTML for the form looks like:

```
<form method="post" action="cgi-bin/form.rb" enctype="application/x-www-form-urlencoded" >
  <input name="email" type="email" placeholder="Email (optional)">
  <textarea name="message" required="required" autofocus="autofocus"
                                               placeholder="Message/suggestion/feedback/questions"></textarea>
  <input type=submit value="Submit">
</form>

```  

In the first line we setup a form element with [POST]() method and [action]() is 
set to the cgi script path relative to the server root. Do not add `/` before 
specifying the path of the script location e.g. use `/cgi-bin/script.rb` instead
of `cgi-bin/script.rb`. Using the former will make the daemon look for a script.rb 
in /usr/lib/cgi-bin/ instead of looking in a subfolder of server root. The error shows up 
in the error log as a cgid error with the message `AH01264: script not found 
or unable to stat: /usr/lib/cgi-bin/one.html`. Also, we setup the [enctype]() to 
`application/x-www-form-urlencoded`

Next we have two fields - an [input box]() with [type]() set to `email` (to make sure 
the user enters something that looks like an email and we add the placeholder text.
 Second is the [textarea] field which is [required](), has a name and a placeholder 
text and is auto focused. `textarea` element provides a resizable box. 

## Redirecting to the same page with "Message submitted" notice

## Saving the data to dynamo db

## Receiving notifications on new messages - using SNS notifications
