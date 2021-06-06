require 'aws-sdk-lambda'
require './zip_files'


class LambdaHandler
  def initialize(zip_filename="", *files_to_zip)
    @files_to_zip = files_to_zip
    @zip_filename = zip_filename
    Aws.config.update(
      region: 'us-east-1',
      credentials: Aws::InstanceProfileCredentials.new
    )

    @lambda_client = Aws::Lambda::Client.new
  end

  def zip_files
    zipper = ZipFilesRec.new(*@files_to_zip, @zip_filename)
    zipper.zip
    @zip_filename = zipper.zip_filename
  end

  def deploy_lambda
    zip_files
    response = @lambda_client.create_function({
      function_name: "a93_message_handler", 
      runtime: "ruby2.7", 
      role: "arn:aws:iam::979558485280:role/a93_messaging_lambda_role", 
      handler: "message_handling_lambda.handler",
      code: { 
        zip_file: File.open("#{@zip_filename}", "rb"),
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

  def update_function_code
    zip_files
    resp = @lambda_client.update_function_code({
      function_name: "a93_message_handler", 
      zip_file: File.open("#{@zip_filename}", "rb"),
    })
  end

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
    response = @lambda_client.list_functions
  end

  def create_trigger
    response = @lambda_client.create_event_source_mapping({
      event_source_arn: "arn:aws:dynamodb:us-east-1:979558485280:table/A93/stream/2021-06-06T05:26:27.307",
      function_name: "a93_message_handler", 
      enabled: true,
      batch_size: 10,
      maximum_batching_window_in_seconds: 1,
      starting_position: "LATEST", 
      maximum_record_age_in_seconds: 60,
      bisect_batch_on_function_error: true,
    })
  rescue Aws::Lambda::Errors::AccessDeniedException => e
    puts "Error in adding target to the function"
    puts e.message, e.class
  rescue Aws::Lambda::Errors::InvalidParameterValueException => e
    puts "Error in adding target to the functions"
    puts e.message, e.class
  ensure
    response
  end

  private :zip_files
end

