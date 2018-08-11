import json
from typing import Optional

from api import ddb
from api.utils import response
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
        return response(400, f"invalid status {status}")

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
    ddb.get_active_job(worker)  # Just ensure that it exists.
    ddb.update_active_job(worker, status)


def _finalize(worker: str, status: int, url: Optional[str]) -> None:
    """
    Mark a job as complete and move it from the active job table.
    Also comment on the job's Reddit post.
    """
    job = ddb.get_active_job(worker)

    if status == SUCCEEDED and url:
        comment_link(job, url)

    ddb.move_active_completed(job, status == SUCCEEDED)
