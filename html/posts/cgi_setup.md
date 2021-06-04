# Processing form inputs using CGI scripts

While building this blog, I had to be able to store the messages that visitors 
decided to send me. So, I decided to use [CGI](https://httpd.apache.org/docs/current/howto/cgi.html) scripts to process the form data and 
store the messages in [dynamo db](https://aws.amazon.com/dynamodb/) (for free, thanks to AWS's free tier offering).

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
statements to make the facilities in [URI](https://docs.ruby-lang.org/en/2.1.0/URI.html) 
and [JSON](https://ruby-doc.org/stdlib-3.0.1/libdoc/json/rdoc/JSON.html) mdoule 
available to our script. In the next line we [open a file](https://ruby-doc.org/core-2.5.0/File.html#method-c-new) 
in [write-only mode](https://man7.org/linux/man-pages/man2/open.2.html) 
(and [creating it](https://man7.org/linux/man-pages/man2/open.2.html) if it doesn't 
already exist) and then we [set its permission](https://man7.org/linux/man-pages/man2/open.2.html) 
to 0666 allowing everybody to read 
and write to this file. The name of the file is set to the time at which the script 
runs using [`Time.now`]() (it is not a good practice to use this method as it becomes unreliable with 
increasing load. But it suffices for the current example). In the next line we are 
reading the request body from the STDIN using `gets.chomp` (see this [StackOverflow 
answer](https://stackoverflow.com/questions/3836828/how-to-parse-the-request-body-using-python-cgi)) 
and then we decode it 
from the [url encoded form](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/form#attr-enctype) 
using `URI.decode_www_form` and we convert it to a dictionary 
using `to_h` method. Once that is done, we are using the `JSON.dump` method to 
dump the contents of the hash to the open file handle in the JSON format. The nice thing 
about using this form is that we don't have to close the file explicitly and it is 
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
  <textarea name="message" 
            required="required" 
            autofocus="autofocus"
            placeholder="Message/suggestion/feedback/questions"
            maxlength=500 
            minlength=50></textarea>
  <input type=submit value="Submit">
</form>

```  

In the first line we setup a form element with [POST](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods/POST) method and the  
[action](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/form#attr-action) 
is set to the cgi script path relative to the server root. Do not add `/` before 
specifying the path of the script location e.g. do not use `/cgi-bin/script.rb` instead
of `cgi-bin/script.rb`. Using the former will make the daemon look for a script.rb 
in /usr/lib/cgi-bin/ instead of looking in a subfolder of server root. The error shows up 
in the error log as a cgid error with the message `AH01264: script not found 
or unable to stat: /usr/lib/cgi-bin/filename`. Also, we setup the enctype to 
`application/x-www-form-urlencoded` which is a default value, anyhow.

Next we have two fields - an [input box](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input) 
with [type](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input/email) 
set to `email` (to make sure the user enters something that looks like an email 
and we add the placeholder text.)
Second is the [textarea](https://developer.mozilla.org/en-US/docs/Web/HTML/Element/textarea) 
field which is required, has a name and a placeholder 
text and is auto focused. `textarea` element provides a resizable box. We will turn off 
this feature using CSS.

## Redirecting to the same page with "Message submitted" notice

## Saving the data to dynamo db
To save our messages, we are using dynamo db which is a managed NoSQL database 
service from AWS -> meaning we are going to store our messages in JSON documents.
Keep the SDK for [Ruby documentation](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html) open 
to get help with API call parameter names etc.

We will start by adding a barebones policy with permission to list the tables 
to the instance profile attached to our machine and then keep on adding 
permissions as required.

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "dynamodb:ListTables",
            "Resource": "*"
        }
    ]
}
``` 

To test if everything is working fine, we start with the following Ruby script

```
require 'aws-sdk-core'
require 'aws-sdk-dynamodb'

credentials = Aws.config.update(
  region: "us-east-1",
  credentials: Aws::InstanceProfileCredentials.new
)

dynamo_client = Aws::DynamoDB::Client.new

puts dynamo_client.list_tables
```

## Add code description below## 

Put the above code in a file and run it with `ruby filename.rb`. If it throws error 
about *uninitialized constants* make sure that you included the file  and that 
the required ruby gems are 
installed by running `gems list aws-sdk-dynamodb`. If it is not installed, then 
install it by running `[sudo] gem install aws-sdk-dynamodb`. If it is throwing 
a LoadError make sure that you have spelled the names correctly.

Running the script should give you an output like this (assuming there are no 
tables in this region):

```
{:table_names=>[], :last_evaluated_table_name=>nil}
```

Now we need to create a table and for that we need to add a permission to our instance 
role. Add the following policy that allows the instance profile to create a table 
named "A93"

```
{
    "Sid": "VisualEditor0",
    "Effect": "Allow",
    "Action": "dynamodb:CreateTable",
    "Resource": "arn:aws:dynamodb:us-east-1:979558485280:table/A93"
}
```

## Receiving notifications on new messages - using SNS notifications
