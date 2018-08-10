import boto3

ddb = boto3.resource("dynamodb")
active_job_table = ddb.Table("replay-bot-jobs-active")
complete_job_table = ddb.Table("replay-bot-jobs-complete")
worker_table = ddb.Table("replay-bot-workers")
