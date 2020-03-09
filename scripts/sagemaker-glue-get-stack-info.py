###
### sagemaker-glue-get-stack-info.py
###
import boto3,json

stack={}

# Get S3 Bucket
s3 = boto3.client('s3')
response = s3.list_buckets()
bucket_name = [k['Name'] for k in response['Buckets'] if 'glue-labs' in k['Name']][0]
stack['S3Bucket']=bucket_name

print (json.dumps(stack))
with open('stack-info.json', 'w') as f:
    json.dump(stack, f)
