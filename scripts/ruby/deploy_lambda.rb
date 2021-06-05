require 'aws-sdk-lambda'
require './zip_files'

zipper = ZipFilesRec.new(*ARGV[0..-2], ARGV[-1])
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

puts response
