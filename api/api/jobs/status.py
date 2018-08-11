import json
from typing import Optional

from api.ddb import active_job_table, complete_job_table
from api.utils import check_ddb_response, nowstamp, response
from api.reddit import comment_link
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
        if isinstance(e, KeyError):
            print(f"KeyError: {e}")
        else:
            print(e)
        print(f"body {event['body']} is invalid")
        return response(400, "invalid request body")

    if status < PENDING or status > FAILED:
        print(f"invalid status {status}")
        return response(400, f"inalid status {status}")

    if status < SUCCEEDED:
        try:
            _update(worker, status)
        except Exception as e:
            return response(500, e)
        return response(200, "update active -> active")
    else:
        try:
            _finalize(worker, status, body.get("url"))
        except Exception as e:
            return response(500, e)
        return response(200, "update active -> complete")


def _update(worker: str, status: int) -> None:
    """
    Update an active job's status.
    """
    resp = check_ddb_response(
        active_job_table.get_item(Key={"worker": worker}), f"get active job by {worker}"
    )
    if not resp or "Item" not in resp:
        raise Exception(f"active job by {worker} not found")

    if not check_ddb_response(
        active_job_table.update_item(
            Key={"worker": worker},
            UpdateExpression="SET job_status = :status, updated_at = :now",
            ExpressionAttributeValues={":status": status, ":now": nowstamp()},
        ),
        f"update active job by {worker} to {status}",
    ):
        raise Exception("DynamoDB error: update active -> active failed")


def _finalize(worker: str, status: int, url: Optional[str]) -> None:
    """
    Mark a job as complete and move it from the active job table.
    Also comment on the job's Reddit post.
    """
    resp = check_ddb_response(
        active_job_table.get_item(Key={"worker": worker}), f"get active job by {worker}"
    )
    if not resp or "Item" not in resp:
        raise (f"active job by {worker} not found")

    if status == SUCCEEDED and url:
        reddit.comment_link(resp["Item"], url)

    resp = check_ddb_response(
        complete_job_table.put_item(
            Item={**resp["Item"], "job_status": status, "updated_at": nowstamp()}
        ),
        f"copy active job by {worker} to completed table",
    )
    if not resp:
        raise Exception("DynamoDB error: copy active -> complete failed")

    if not check_ddb_response(
        active_job_table.delete_item(Key={"worker": worker}),
        f"delete active job by {worker}",
    ):
        raise Exception("DynamoDB error: delete active failed")
