# This class handles communication with AWS DynamoDB for my personal website. It 
# provides functionality to create a table, write to and read from the table (no 
# update or delete methods are there). The credentials are retrieved from the 
# EC2 instance role.

# Usage: 
# handler = DynamoHandler.new(region_code)
# handler.create_table(table_name)
# handler.put_item(table_name, json_document)
# handler.read_item(table_name, id)

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

