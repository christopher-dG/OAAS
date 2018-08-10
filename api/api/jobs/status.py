import json

from api.ddb import active_job_table, complete_job_table
from api.utils import check_ddb_response, nowstamp
from api.jobs import PENDING, SUCCEEDED, FAILED


def handler(event, context):
    """
    Lambda function entrypoint for /jobs/status.
    The request body should contain the worker ID and the new status.
    The status codes are defined in __init__.py.
    """
    try:
        body = json.loads(event["body"])
        status = int(body["status"])
        worker = body["worker"]
    except Exception as e:
        print(e)
        print(f"body {event['body']} is invalid")
        return {"statusCode": 400}

    if status < PENDING or status > FAILED:
        print(f"invalid status {status}")
        return {"statusCode": 400}

    if status < SUCCEEDED:
        if _update(worker, status):
            return {"statusCode": 200}
    else:
        if _finalize(worker, status):
            return {"statusCode": 200}

    return {"statusCode": 500}


def _update(worker: str, status: int) -> bool:
    """
    Update an active job's status.
    """
    resp = check_ddb_response(
        active_job_table.get_item(Key={"worker": worker}), f"get active job by {worker}"
    )
    if not resp or "Item" not in resp:
        print(f"active job by {worker} not found")
        return False

    return bool(
        check_ddb_response(
            active_job_table.update_item(
                Key={"worker": worker},
                UpdateExpression="SET job_status = :status, updated_at = :now",
                ExpressionAttributeValues={":status": status, ":now": nowstamp()},
            ),
            f"update active job by {worker} to {status}",
        )
    )


def _finalize(worker: str, status: int) -> bool:
    """
    Mark a job as complete and move it from the active job table.
    """
    resp = check_ddb_response(
        active_job_table.get_item(Key={"worker": worker}), f"get active job by {worker}"
    )
    if not resp or "Item" not in resp:
        print(f"active job by {worker} not found")
        return False

    resp = check_ddb_response(
        complete_job_table.put_item(
            Item={**resp["Item"], "job_status": status, "updated_at": nowstamp()}
        ),
        f"copy active job by {worker} to completed table",
    )
    if not resp:
        return False

    return bool(
        check_ddb_response(
            active_job_table.delete_item(Key={"worker": worker}),
            f"delete active job by {worker}",
        )
    )
