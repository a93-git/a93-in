require 'aws-sdk-sns'

def handler(event:, context:)
  Aws.config.update({
    "region": "us-east-1"
  })

  sns_client = Aws::SNS::Client.new 
  messages = []

  begin
    event["Records"]&.each do |record|
      messages.append({
        "email" => record["dynamodb"]["NewImage"]["email"]&.values,
        "message" => record["dynamodb"]["NewImage"]["message"]&.values,
        "id" => record["dynamodb"]["NewImage"]["id"]&.values
      })
    end
  rescue Exception => e
    puts "Error in parsing the event data"
    puts e.message, e.class
  end

  begin
    response = sns_client.publish({
      topic_arn: "arn:aws:sns:us-east-1:979558485280:a93-topic",
      message: messages.to_s, 
      subject: "You have a new message on #{Time.now.strftime("%Y-%m-%d")}"
    })
  rescue Exception => e
    puts "Error in parsing the vent data"
    puts e.message, e.class
  end

  response.message_id
end

