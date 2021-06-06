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

In order to be able to trigger a lambda function, we need to have a function in the 
first place. We will start with creating a function on the local system and then 
deploying it using AWS CLI (which will use the IAM role attached the EC2 instance 
for credentials). We will use AWS CLI to test this function and after that we will 
set up the dynamo DB triggers

Let's start with a barebones lambda function by creating a file named lambda_handler.rb
 that contains the following code:

```
def lambda_handler(event:, context:)
  puts "Yo"                                                                                          
end                                                                                                  
```

This function in its current state will simply print "Yo" when tested. We will 
flesh out this function in due time. For now we will deploy this function to 
get the workflow setup. For that we will create a Ruby script that zips the 
function code along with dependencies and uploads it to AWS Lambda to create 
a function.

1. Zip the function code. To do this we will need to install the `rubyzip` gem 
using `sudo gem install rubyzip`. Add the following code to the deployment Ruby 
script (not the lambda function code)

```
require 'zip'                                                                                         
                                                                                                      
files_to_zip = ARGV[0..-2]                                                                            
zip_filename = ARGV[-1]                                                                               
                                                                                                      
files_to_zip.each do |fn|                                                                             
  Zip::File.open("#{zip_filename}.zip", Zip::File::CREATE) do |zfh|                                   
    zfh.get_output_stream("#{fn}") do |fh|                                                            
      fh.write(File.open("#{fn}").read)                                                               
    end                                                                                               
  end                                                                                                 
end
```

In the above code snippet, we are taking in a list of files that need to be 
zipped along with the zip filename and then we iterate through each of the files 
provided as the argument and add them to the zip filename. If the zip file doesn't 
exist, it will be created. If it exists, files will be added to it. The `get_output_stream` 
method opens a handle to a file `#{fn}` inside the newly created/opened zip 
file to which we then dump the contents of the `#{fn}` file as provided on the 
commandline. Using the same variable name at both places ensures that the filename 
is same inside zip file as well. The problem with the above script is that it doesn't 
zip directories. If we provide it with a directory, it will throw an error. In order 
to fix that I am going to use the file tree generating class from my previous post 
and `require` it into my current file to access it. After using it, the code looks like:

```
require 'zip'
require './generate_file_tree'

class NoFilesToZip < Exception
end

class NoZipFileName < Exception
end

files = ARGV[0..-2]
zip_filename = ARGV[-1]

raise NoFilesToZip if files == nil
raise NoZipFileName if zip_filename == nil

begin
  files_to_zip = []
  files.each do |fn|
    if File.directory?(fn)
      files_to_zip += GenerateFileTree.new([]).rec_listing(fn)
    else
      files_to_zip << fn
    end
  end
ensure
  files_to_zip
end

files_to_zip.each do |fn|
  puts "Compressing #{fn}..."
  Zip::File.open("#{zip_filename}.zip", Zip::File::CREATE) do |zfh|
    zfh.get_output_stream("#{fn}") do |fh|
      fh.write(File.open("#{fn}").read)
    end
  end
end
```

In the modified code for zipping files, we have add our generate_file_tree class 
and we are using it to get all the files recursively. In the constructor we see
that there is an empty array passed, that is supposed to be a list of regex strings 
to exclude from the file list. Here we are not excluding anything. Once we have 
the list of files to zip, we are proceeding as before to add all of them to the zip 
file. Notice that I have added a puts statement within the `files_to_zip` block to 
print out the name of the file it is currently compressing.

Besides these modifications, I have also added two error classes to denote that either
 the list of files to zip is missing or the zip filename is missing - in either case 
an error will be raised. We could have used a single error class here but I chose 
to go with two to emphasize that the first file is the one to be zipped and the last 
one will be the name of the zip file i.e. if only one parameter is provided it 
will throw the `NoZipFileName` error and if zero parameters are provided it will 
throw `NoFilesToZip` error.

Now that we have our zip functionlity, we need to use it to create a deployment package 
and create a lambda function.

Following AWS' documentation on [deploying a Lambda function with Ruby
runtime](https://docs.aws.amazon.com/lambda/latest/dg/lambda-ruby.html), we now 
need to install any dependencies in a folder structure `vendor/bundle` in the 
current directory. Right now we don't have any dependencies so we will skip any 
dependency installation and use only our function file. 

In order to create and deploy a Lambda function, add the following code:

```
Aws.config.update(
  region: 'us-east-1',
  credentials: Aws::InstanceProfileCredentials.new
)

lambda_client = Aws::Lambda::Client.new

response = lambda_client.create_function({
  function_name: "a93_message_handler", 
  runtime: "ruby2.7", 
  role: "arn:aws:iam::979558485280:role/a93_messaging_lambda_role", 
  handler: "message_handling_lambda.handler",
  code: { 
    zip_file: File.open("#{zip_filename}.zip", "rb"),
  },
  description: "Sends SNS notification when a new message ends up in DynamoDB",
  timeout: 30,
  memory_size: 128,
  publish: true,
  package_type: "Zip"
})
```

Here we are setting up the region and the credentials for script wide use with 
Aws.config.update and then we create a client to the lambda function. We call 
the `create_function` method to create the function. A few important things to 
note here are:

1. The role ARN is hardcoded because creating a new role from our script means that 
we need to provide IAM permissions to our EC2 instance role which is not required here 
and doesn't seem like a good idea. So, we have a role configured in IAM separately 
for lambda function. At this point this role has *zero policies* attached to it meaning 
it has no permissions.

2. In the code section, we need to provide a base64 encoded stream of zip file 
containing the function code and dependencies. It means we need to open the file to 
read in binary mode and then provide the file handle to AWS SDK to handle the 
upload.

3. The handler of a lambda function is of the form `function_file_name.handle_name` 
and that's what we have added here. We will change it to a variable value in next 
iterations if required, else we will leave the hardcoded value

If we execute our script now, it will throw us an `AccessDeniedException` as we 
haven't added the Lambda publish permssion to our EC2 role. Create a new policy with 
the following statement and attach it to the EC2 role:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "lambda:CreateFunction",
                "iam:PassRole"
            ],
            "Resource": [
                "arn:aws:lambda:us-east-1:979558485280:function:a93_message_handler",
                "arn:aws:iam::979558485280:role/a93_messaging_lambda_role"
            ]
        }
    ]
}
```

In this policy we are stating that the bearer of this policy is allowed to create a 
lambda function named a93_message_handler and to pass a role named `a93_messaging_lambda_core`. 
It is possible to restrict this policy further but we will stop here for now and go 
deploy our function by calling our script. Our script invocation will look like:

```
ruby script_name.rb function_file.rb zip_filename
```

Calling it will create a zip file `zip_filename.zip` with the `function_file.rb` 
inside it. You can verify that the function has been created by going to the 
AWS console and navigating to the Lambda service page. 

Now that our function is created, you can invoke it from console by using the 'Test' 
functionality and you will see the output `Yo` in the execution log on the same 
page. We can now work on making our lambda function 
do what we want it to do. But before that we will refactor our deploy script, add 
error handling, update our EC2 role policy to allow listing of functions and to 
publish new version of the same lambda function and to invoke the lambda function 
from our ruby script and update the Lambda execution role to be able to log its 
output to cloudwatch logs.

To refactor our deploy script, we will start by adding some rescue statements to 
create function call and our deploy script file becomes:

```
require 'aws-sdk-lambda'                                                                            
require './zip_files'                                                                               
                                                                                                    
zipper = ZipFilesRec.new(\*ARGV[0..-2], ARGV[-1])                                                     
zipper.zip                                                                                          
zip_filename = zipper.zip_filename   

Aws.config.update(                                                                                                  
  region: 'us-east-1',                                                                              
  credentials: Aws::InstanceProfileCredentials.new                                                  
)                                                                                                   
                                                                                                    
lambda_client = Aws::Lambda::Client.new                                                             
                                                                                                    
begin                                                                                               
  response = lambda_client.create_function({                                                        
    function_name: "a93_message_handler",                                                           
    runtime: "ruby2.7",                                                                             
    role: "arn:aws:iam::979558485280:role/a93_messaging_lambda_role",                               
    handler: "message_handling_lambda.handler",                                                     
    code: {                                                                                         
      zip_file: File.open(zip_filename, "rb"),                                                 
    },                                                                                              
    description: "Sends SNS notification when a new message ends up in DynamoDB",                   
    timeout: 30,                                                                                    
    memory_size: 128,                                                                               
    publish: true,                                                                                  
    package_type: "Zip"                                                                             
  })                                                                                                
rescue Aws::Lambda::Errors::ResourceConflictException => e                                          
  puts "Error in creating the Lambda function"                                                      
  puts e.message, e.class                                                                           
rescue Aws::Lambda::Errors::AccessDeniedException => e                                              
  puts "Access denied error while creating the Lambda function"                                     
  puts e.message, e.class                                                                           
rescue Exception => e                                                                               
  puts "Error occured while creating the Lambda function"                                           
  puts e.message, e.class                                                                           
ensure                                                                                              
  response                                                                                          
end     
```

In the code above you can see that we have moved our zipping code block to a 
class of its own and we are using that class to zip the files and get the zip_filename 
as well. Aws.config.update remains the same. In the `create_function` section, 
We are handling errors using 3 rescue blocks - one for resource conflict (function 
already exists), another for access denied errors e.g. not allowed to invoke or 
publish or create or pass role etc. If any unexpected errors occur, we handle it in the 
third block and re-raise it to halt program execution and inform the user.

Another change is in the `code: {}` section where I have changed the filename in
 the`File.open` method call to simply the variable name. This change comes as an 
effect of moving the zipping code to separate class which provides an attribute 
accessor to access the zip_filename. This filename already comes with ".zip" suffix.

Also, the extracted class looks like:

```
require 'zip'
require './generate_file_tree'                                                                      
                                                                                                    
class ZipFilesRec                                                                                   
  attr_reader :zip_filename                                                                         
                                                                                                    
  def initialize(\*files, zip_filename)                                                              
    @files = files                                                                                  
    @zip_filename = "#{zip_filename}.zip"                                                           
    @files_to_zip = []                                                                              
  end                                                                                               
                                                                                                    
  def get_files_to_zip                                                                              
    @files.each do |fn|                                                                             
      if File.directory?(fn)                                                                        
        @files_to_zip += GenerateFileTree.new([]).rec_listing(fn)                                   
      else                                                                                          
        @files_to_zip << fn                                                                         
      end                                                                                           
    end                                                                                             
  ensure                                                                                            
    @files_to_zip                                                                                   
  end                                                                                               
                                                                                                    
  def zip                                                                                           
    get_files_to_zip.each do |fn|                                                                   
      puts "Compressing #{fn}..."                                                                   
      Zip::File.open("#{@zip_filename}", Zip::File::CREATE) do |zfh|                            
        zfh.get_output_stream("#{fn}") do |fh|                                                      
          fh.write(File.open("#{fn}").read)                                                         
        end                                                                                         
      end                                                                                           
    end                                                                                             
  rescue Exception => e                                                                             
    puts "Error in compressing file"                                                                
    raise                                                                                           
  end                                                                                               
                                                                                                    
  private :get_files_to_zip                                                                         
end     
``` 

Here we initialize the class with a set of files/folders to compress and a name 
for the zip file. Then we have a private method get_files_to_zip which creates an 
array of filenames with their paths to be zipped. We also have a zip method where 
we iterate through the list of files and keep adding it to our archive file. 

The `private` keyword at the bottom is used to signify that the following method names 
are private.

We will also refactor our `deploy_lambda` script and put it into a class (not required 
but just to bundle things up) and the code will become:

```
require 'aws-sdk-lambda'
require './zip_files'

class LambdaHandler
  def initialize(zip_filename="", \*files_to_zip)
    @files_to_zip = files_to_zip
    @zip_filename = zip_filename
    Aws.config.update(
      region: 'us-east-1',
      credentials: Aws::InstanceProfileCredentials.new
    )
    @lambda_client = Aws::Lambda::Client.new
  end

  def deploy_lambda
    zipper = ZipFilesRec.new(*files_to_zip, zip_filename)
    zipper.zip
    zip_filename = zipper.zip_filename

    response = @lambda_client.create_function({
      function_name: "a93_message_handler", 
      runtime: "ruby2.7", 
      role: "arn:aws:iam::979558485280:role/a93_messaging_lambda_role", 
      handler: "message_handling_lambda.handler",
      code: { 
        zip_file: File.open("#{zip_filename}", "rb"),
      },
      description: "Sends SNS notification when a new message ends up in DynamoDB",
      timeout: 30,
      memory_size: 128,
      publish: true,
      package_type: "Zip"
    })
  rescue Aws::Lambda::Errors::ResourceConflictException => e
    puts "Error in creating the Lambda function"
    puts e.message, e.class
  rescue Aws::Lambda::Errors::AccessDeniedException => e
    puts "Access denied error while creating the Lambda function"
    puts e.message, e.class
  rescue Exception => e
    puts "Error occured while creating the Lambda function"
    puts e.message, e.class
  ensure 
    response
  end
end

```

Here we have stuffed everything in a class, wrapped our API calls and their 
rescue blocks into method definitions and put the client configuration in the 
initialize block. Also, the zip_filename and the \*files_to_zip arguments are 
not required anymore (don't need to specify on the command line, don't need to 
provide while creating an object from this class). If and when we want to create 
a function, we will create an object with those parameters and use the methods 
that use these parameters i.e. the deploy_lambda function for now. Region value 
is hardcoded to 'us-east-' because we are going to be working only in this region.

Now that we are done with the refactoring for now, let's see what changes we need 
to make to the EC2 role and the lambda execution role. To allow the bearer of the 
instance role to be able to publish a version, list and invoke the lambda function, 
update the lambda policy attached to the EC2 role with the following statement:

{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "lambda:CreateFunction",
                "iam:PassRole",
                "lambda:InvokeFunction",
                "lambda:PublishVersion"
            ],
            "Resource": [
                "arn:aws:lambda:us-east-1:979558485280:function:a93_message_handler",
                "arn:aws:iam::979558485280:role/a93_messaging_lambda_role"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": "lambda:ListFunctions",
            "Resource": "*"
        }
    ]
}

This policy has permissions to invoke and publish only our message handler function 
and to list functions in our account.

In order to allow our Lambda function to create a log group, and then a log stream 
and then allow it to put log events into it, we will attach an AWS managed policy
 "AWSLambdaBasicExecutionRole" that has the policy for our exact requirements. The 
policy statement in this policy reads:

```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
```

The "\*" in the `Resource` section is what makes this policy attachable to any 
Lambda function (meaning the lambda function can create a log group and stream 
for itself), and, since creation of log streams and putting events there is 
handled by AWS (we can also do that, be we won't), we can trust it to not put 
spammy logs :)

With that we have the required policies in place, our script is working as expected 
and we have tested our function by invoking it from the AWS GUI console. Let's add the 
functionality to list the functions in our account and then to invoke our 
function from our ruby script. Add the following methods to the class definition:

```
def invoke(function_name)
  response = @lambda_client.invoke({
    function_name: function_name, 
    invocation_type: "RequestResponse", 
    log_type: "Tail", 
    payload: "",
  })
  response
end

def list_functions
  @lambda_client.list_functions
end
```

The invoke function sends a function name to invoke with invocation type set to
 "RequestResponse" which means we will wait for the execution to finish and the 
`log_type` parameter is set to `Tail` meaning we will get the 'tail' of the log 
which will be the last 4 KB of the execution logs (in Base64 encoded format). Payload is empty.

The list_functions method is just a wrapper around the API call.

To invoke these functions and to print the response, add the following code to the 
deployment script file (outside the class definition):

```
lh = LambdaHandler.new

invoke_response = lh.invoke("a93_message_handler")
puts Base64.decode64(invoke_response[:log_result])

puts 

list_response = lh.list_functions
list_response[:functions].each do |fun|
  print "#{fun[:function_name]}\t#{fun[:function_arn]}\n"
end
```

Here we are creating a LambdaHandler object and then invoking it. Since the log 
output is in base64 encoded format, we decode it with `Base64.decode` before 
printing. Also, we list the functions and print the function name and arn for 
each of the function in our account in the 'us-east-1' region

This marks the end of the deployment pipeline setup. Now we have everything we need 
to deploy our functions. I am going to be working on building our actual lambda function 
now. 


