# Processing form inputs using CGI scripts

While building this blog, I had to be able to store the messages that visitors 
decided to send me. So, I decided to use [CGI](https://httpd.apache.org/docs/current/howto/cgi.html) scripts to process the form data and 
store the messages in [DynamoDB](https://aws.amazon.com/dynamodb/) (for free, thanks to AWS's free tier offering).

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
STDOUT. This response will be sent back to the browser and rendered as 'Hello, World'

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

## Saving the data to Dynamo DB
To save our messages, we are using Dynamo DB which is a managed NoSQL database 
service from AWS -> meaning we are going to store our messages in JSON documents.
Keep the SDK for [Ruby documentation](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html) open 
to get help with API call parameter names etc.

We will start by adding a barebones policy with permission to list the tables 
to the instance profile attached to our machine and then keep on adding 
permissions as required. So, the credentials will come from the attached instance 
profile, no need to create any access keys.



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

-  Table - Collection of items
-  Items - Individual record
-  Attributes - Properties of the item

Example - A *Student* table can have an item to represent a specific student and it 
may have attributes e.g. *name*, *student_id* etc. Students are uniquely identifiable 
using a key called the *Primay key*. The primay key can be a single attribute in which 
case it is called a *Partition key* or it can be composed of two attributes in which case 
it is called as a *Composite key*. The primary key of an item must be unique to it. In our 
example case if we have a table for students of only one class where each student is
numbered from 1 to n, the primary key can be the student number itself. If there were 
a situation where more than one student could have the same number (yes, it is not 
a good example but I am not able to come up with anything good at this moment) then in 
that case we could use another student attribute e.g. year, class etc. to uniquely 
identify individual students. In this case the primary key would consist of a 
partition key and a *sort key*. Primary key is required so that DynamoDB can 
determine where to store the data in physical storage internal to DynamoDB

Refer to this
[document](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.CoreComponents.html) 
to read on the details of the components of DynamoDB

In order to create the table, we need to provide **attribute definitions**, **table name**
 and a **key schema** (see this document for [request syntax in Ruby](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html#create_table-instance_method)). The key schema refers to the 
attribute name and the attribute type of the attribute(s) that will serve as the 
primary key and that is the *only* schema we need to provide because besides 
the primary key, the table is schemaless - meaning we can have different 
attributes for different items. Individual attribute definitions are a dictionary consisting 
of the name and type of the attribute.

In our case JSON documents are items and its first level fields are attributes. 
We will have a message attribute that holds the message, an email field that may or 
may not be present. We will add an
[UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier) as an additional attribute to serve as the 
primary key. 

Note - I am storing the message in the item itself instead of storing it in a file 
in an S3 bucket and the object URL in the item because AWS allows us to have each 
item of upto 400KB and our individual messages are limited to 500 characters - so we 
are well within our limits (even if [UTF-32](https://en.wikipedia.org/wiki/UTF-32) 
encoding is used that takes 4 bytes per [code point](https://en.wikipedia.org/wiki/Code_point), 
which we are not using)

Add the code below to the script and it will create a new table with name "A93" 
when executed:

```
response = dynamo_client.create_table({
  attribute_definitions: [                                                                            
    {                                                                                                 
      attribute_name: "id",                                                                           
      attribute_type: "S"                                                                             
    }                                                                                                 
  ],                                                                                                  
  table_name: "A93",                                                                                  
  key_schema: [                                                                                       
    {                                                                                                 
      attribute_name: "id",                                                                           
      key_type: "HASH"                                                                                
    }                                                                                                 
  ],                                                                                                  
  billing_mode: "PROVISIONED",                                                                        
  provisioned_throughput: {                                                                           
    read_capacity_units: 5,                                                                           
    write_capacity_units: 5                                                                           
  }                                                                                                   
})                                                                                                    
```

In the above call to the `create_table` api I have set the billing mode to 
provisioned and set the read and write capacity units. I don't expect a heavy 
traffic to the blog and neither am I reading my messages a gazillion times a day 
so the provisioned read and write capacity units should suffice. You can read more 
about [read and write capacity
units here](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/HowItWorks.ReadWriteCapacityMode.html#HowItWorks.ProvisionedThroughput.Manual) 

Running the scipt at this point should create a new table called "A93". Now we will 
add a single item to this table. In order to be able to put item, we need to add 
the required permission to the instance role. Add the following statement to the role:

```
{
    "Sid": "VisualEditor0",
    "Effect": "Allow",
    "Action": [
        "dynamodb:CreateTable",
        "dynamodb:PutItem"
    ],
    "Resource": "arn:aws:dynamodb:us-east-1:123456789012:table/A93"
}
```

Once done, we can update our code to write items to the DynamoDB. But before adding 
code to do that, we wrap our create_table API call in a `begin/rescue` block to catch 
any errors that might occur. Our create_table API call should look like:

```
begin                                                                                                 
  response = dynamo_client.create_table({                                                             
    attribute_definitions: [                                                                          
      {                                                                                               
        attribute_name: "id",                                                                         
        attribute_type: "S"                                                                           
      }                                                                                               
    ],                                                                                                
    table_name: "A93",                                                                                
    key_schema: [                                                                                     
      {                                                                                               
        attribute_name: "id",                                                                         
        key_type: "HASH"                                                                              
      }                                                                                               
    ],                                                                                                
    billing_mode: "PROVISIONED",                                                                      
    provisioned_throughput: {                                                                         
      read_capacity_units: 5,                                                                         
      write_capacity_units: 5                                                                         
    }                                                                                               
  })                                                                                                
rescue Aws::DynamoDB::Errors::ResourceInUseException => e                                           
  puts "Table already exists"                                                                       
  puts e.message, e.class                                                                           
  exit                                                                                              
rescue Exception => e                                                                               
  puts "Error occurred while creating table"                                                        
  puts e.message, e.class                                                                           
  raise 
end

puts response unless response == nil
```

Here we make the api call in the begin block and catch any errors in the rescue block. 
We can also catch specific errors for example if the table already exists then we get 
a resource already exists exception and when that error occurs we rescue it and print 
out the error message and then exit the program execution. If some other error occurs
 which we are not expecting, we are also catching that in the last rescue block 
and after logging the error, we are re-raising it. In the end we print the response 
if it is not nil

With the create table call fixed, let's add the call to insert the item into the table. 
Add the following code to the script after the create table call:

```
begin                                                                                                 
response = dynamo_client.put_item({                                                                   
  table_name: "A93",                                                                                  
  item: {                                                                                             
    "id": "some-string",                                                                              
    "message": "this is super cool",                                                                  
    "email": "super@duper.com"
  }                                                                                                   
})                                                                                                    
rescue Aws::DynamoDB::Errors::AccessDeniedException => e                                              
  puts e.message, e.class                                                                             
rescue Exception => e
  puts "Error occurred while inserting item to the table"
  puts e.message, e.class
  raise
end                                                                                                   
                                                                                                      
puts response unless response == nil 
```

To *insert* an item in the table, we are using the `put_item` API call which takes 
the `table_name`, `item` document as parameters. Once executed, we will have our 
item created in the table. Check this link for a [full list of parameters](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html#put_item-instance_method) that this method accepts.

We will comeback to this code block later on to add conditions which will only write 
to the table if the id doesn't already exists. In othre words, it won't overwrite my 
messages.

For now, our script is able to create a table and write to the table. Let's add 
functionality to fetch our messages as well. But before we fetch our messages, 
we need to add permission to our instance role to be able to read the items in the table.
 Update our policy statement to include the `dynamodb:GetItem` permission from the 
A93 table

```
{
    "Sid": "VisualEditor0",
    "Effect": "Allow",
    "Action": [
        "dynamodb:CreateTable",
        "dynamodb:PutItem",
        "dynamodb:GetItem"
    ],
    "Resource": "arn:aws:dynamodb:us-east-1:979558485280:table/A93"
}
```

Once done updating the policy, let's update our script to perform the read operation. 
Append the following code to our script to read from the table:

```
begin 
  response = dynamo_client.get_item({                                                                 
    table_name: "A93",                                                                                
    key: {                                                                                            
      "id" => "some-string",                                                                          
    },                                                                                                
  })                                                                                                  
rescue Aws::DynamoDB::Errors::AccessDeniedException => e                                              
  puts "Insufficient permissions to read from the table"                                              
  puts e.message, e.class                                                                             
rescue Exception => e                                                                                 
  raise                                                                                               
end 
```

Here we are trying to read an item from the table with the given id. We are 
rescuing AccessDeniedException in case there are some issues due to an update in 
policy or some other reason. The details for all the possible parameters can be 
read from [this document](https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/DynamoDB/Client.html#get_item-instance_method).

Now we can create tables, write to that table and read from that table. In my particular 
case I am not looking forward to deleting the messages I receive (even mean ones). So, 
I will not be adding the delete functionlity to our script, though, adding it should 
be a trivial task. Similarly, we are not going to update any messages so, no need to 
implement this functionality as well. However, we can if we want to.

Now we will put our individual API calls into methods and bundle these methods in 
a class that can be `require`d in our cgi program. Before doing that, let's modify 
the `put_item` api call to only write if the id doesn't exist. After adding the 
conditional check our code should look like this:

```
begin                                                                                                 
  response = dynamo_client.put_item({                                                                 
    table_name: "A93",                                                                                
    item: {                                                                                           
      "id": "some-string",                                                                            
      "message": "this is super cool",                                                                
      "email": "super@duper.com"                                                                      
    },                                                                                                
    condition_expression: "attribute_not_exists(id)"                                                  
  })                                                                                                  
rescue Aws::DynamoDB::Errors::AccessDeniedException => e                                              
  puts "Insufficient permissions to write to the table"                                               
  puts e.message, e.class                                                                             
  raise                                                                                               
rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => e                                    
  puts "Attribute with the given Id already exists"                                                   
  puts e.message, e.class                                                                             
  raise                                                                                               
rescue Exception => e                                                                                 
  puts "Error occurred while inserting item in the table"                                             
  puts e.message, e.class                                                                             
  raise                                                                                               
end  
```

We have added a condition expression that states that we are only going to insert 
if no items with the given `id` exist. We are using the conditional check on the 
`id` attribute because it is our primary key and guaranteed to be present in any 
item. If any item with the given attribute exists, a `ConditionalCheckFailedException` will 
be raised. We are rescuing this error and after logging the error details (just a put 
statement for now) we re-raise it to be handled by the caller.

After performing our refactoring, the overall class to handle communication with the 
DynamoDB will look like this:

```
#This class handles communication with AWS DynamoDB for my personal website. It
#provides functionality to create a table, write to and read from the table (no
#update or delete methods are there). The credentials are retrieved from th
#EC2 instance role.
                                                                                                   
#Usage:                                                                                            
#handler = DynamoHandler.new(region_code, table_name)                                                          
#handler.create_table 
#handler.put_item(json_document)                                                       
#handler.read_item(id)                                                                 
                                                                                                    
require 'aws-sdk-core'                                                                              
require 'aws-sdk-dynamodb'                                                                          
                                                                                                    
class DynamoHandler                                                                                 
  attr_reader :table_name

  def initialize(region_code, table_name)
    Aws.config.update(                                                                              
      region: region_code,                                                                          
      credentials: Aws::InstanceProfileCredentials.new                                              
    )                                                                                               
    @dynamo_client = Aws::DynamoDB::Client.new                                                      
    @table_name = table_name
  end                                                                                               
                                                                                                    
  def create_table()                                                                      
    response = @dynamo_client.create_table({                                                        
      attribute_definitions: [                                                                      
        {                                                                                           
          attribute_name: "id",                                                                     
          attribute_type: "S"                                                                       
        }                                                                                           
      ],                                                                                            
      table_name: @table_name,                                                                       
      key_schema: [                                                                                 
        {                                                                                           
          attribute_name: "id",                                                                     
          key_type: "HASH"                                                                          
        }                                                                                           
      ],                                                                                            
      billing_mode: "PROVISIONED",                                                                  
      provisioned_throughput: {                                                                     
        read_capacity_units: 5,                                                                     
        write_capacity_units: 5                                                                     
      }                                                                                             
    })                                                                                              
  rescue Aws::DynamoDB::Errors::ResourceInUseException => e
    puts "Table already exists"                                                                     
    puts e.message, e.class                                                                         
    raise                                                                                           
  rescue Exception => e                                                                             
    puts "Error occurred while creating table"                                                      
    puts e.message, e.class                                                                         
    raise                                                                                           
  ensure                                                                                            
    response                                                                                        
  end                                                                                               
                                                                                                    
  def put_item(json_document)                                                           
    response = @dynamo_client.put_item({                                                            
      table_name: @table_name,                                                                       
      item: json_document,                                                                          
      condition_expression: "attribute_not_exists(id)"                                              
    })                                                                                              
  rescue Aws::DynamoDB::Errors::AccessDeniedException => e        
    puts "Insufficient permissions to write to the table"                                              
    puts e.message, e.class                                                                            
    raise                                                                                              
  rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException => e                                   
    puts "Attribute with the given Id already exists"                                                  
    puts e.message, e.class                                                                            
    raise                                                                                              
  rescue Exception => e                                                                                
    puts "Error occurred while inserting item in the table"                                            
    puts e.message, e.class                                                                            
    raise                                                                                              
  ensure                                                                                               
    response                                                                                           
  end                                                                                                  
                                                                                                       
  def read_item(id)                                                                        
    response = @dynamo_client.get_item({                                                               
      table_name: @table_name,                                                                          
      key: {                                                                                           
        "id" => id,                                                                                    
      },                                                                                               
    })                                                                                                 
  rescue Aws::DynamoDB::Errors::AccessDeniedException => e                                             
    puts "Insufficient permissions to read from the table"                                             
    puts e.message, e.class                                                                            
    raise                                                                                              
  rescue Exception => e                                                                                
    puts "Error occurred while reading item from the table"                                            
    puts e.message, e.class                                                                            
    raise                                                                                              
  ensure
    response
  end                                                                                                  
end   
```

In the code above, I have added some comments at the top with the a usage example. 
After that I have moved everything inside the class `DynamoHandler`. There is the 
constructor - `initialize` method which takes in a region and a table name - whether 
existing or the name of a new table; and uses the instance's 
IAM profile to gather credentials and creates a client - an interface - to the 
DynamoDB service. Once the object has been successfully initialized, it can be used 
to create a new table using the `create_table`. This whole setup is for use 
with a very specific usecase and that's why 
instead of generalizing it I have hardcoded the attribute named `id` of type string.
Once we have the table created, we can use the `put_item` or `read_item` methods to 
insert or read from the table by providing a document to insert or an ID to read. 
I have also added ensure statement to make sure that a response is always returned 
even if error occurs (although that doesn't make much sense with our current setup 
as we are re-raising the error and it will cause error at the caller's end as well... 
I will probably remove those raise statements in next iteration)

For now our DynamoHandler class is ready to be used. As a next logical step we 
need to be notified when a new message arrives. We will be using DynamoDB streams 
to trigger a Lambda function whenever a new message comes in and the Lambda function 
will send us an SNS notification via email. [DyanmoDB
streams](https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/streamsmain.html)
 offer [2.5 million requests for free per month](https://aws.amazon.com/dynamodb/pricing/provisioned/) 
and that should be enough for my use case :) 

## Receiving notifications on new messages



