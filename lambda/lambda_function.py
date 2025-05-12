import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('CyberCrowds')  # Make sure this matches your Terraform table

def lambda_handler(event, context):
    try:
        response = table.scan()
        items = response.get('Items', [])
        if not items:
            return {
                "statusCode": 400,
                "body": json.dumps("No ride wait times found.")
            }
        # Simulate processing
        ride_wait_times = {item['ride']: int(item['wait_time']) for item in items}
        recommendations = []
        for ride, wait_time in ride_wait_times.items():
            if wait_time > 45:
                less_busy_ride = min(ride_wait_times, key=ride_wait_times.get)
                if ride != less_busy_ride:
                    recommendations.append(
                        f"{ride} = {wait_time} mins. Try {less_busy_ride} = {ride_wait_times[less_busy_ride]} mins."
                    )
        return {
            "statusCode": 200,
            "body": json.dumps(recommendations or "All rides are fine!")
        }
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps(f"Error: {str(e)}")
        }
