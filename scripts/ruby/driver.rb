require './dynamohandler'
require './deploy_lambda'

#-----------------
# Add new trigger to the function
#-----------------
# lambda_obj = LambdaHandler.new
# lambda_obj.create_trigger

#-----------------
# Add new object to the table
#-----------------
obj = DynamoHandler.new('us-east-1', 'A93')
# 
response = obj.put_item({"message": "This is the third message to trigger the Lambda function using DynamoDB streams.", "id": "dynamo-3"})
# 
 puts response
 
#-----------------
# Update lambda function code
#-----------------
# lh = LambdaHandler.new("message_handler", "message_handling_lambda.rb")
# 
# puts lh.update_function_code

#-----------------
# Invoke lambda function 
#-----------------
 # invoke_response = lh.invoke("a93_message_handler")
 # puts "Tail log of Lambda invocation:"
 # puts Base64.decode64(invoke_response[:log_result])

#-----------------
# List functions
#-----------------
# list_response = lh.list_functions
# list_response[:functions].each do |fun|
  # print "#{fun[:function_name]}\t#{fun[:function_arn]}\n"
# end
