import json
from boto3.dynamodb.conditions import Attr
from typing import Optional

from api.ddb import active_job_table, worker_table
from api.utils import check_ddb_response, nowstamp, response

NO_JOB_FOUND = Exception("no job found")
NO_JOB = response(204, None, quiet=True)


def handler(event, context):
    """
    Lambda function entrypoint for /poll.
    Workers should POST to this endpoint constantly to register their presence.
    The status code is 204 when the server acknowledges the worker,
    but there is no work to be done.
    When the worker has been assigned a job, the status code is 200
    and the body contains the job information.
    """
    try:
        body = json.loads(event["body"])
        worker = body["worker"]
    except Exception as e:
        print(e)
        print(f"{event['body']} is invalid")
        return response(400, "invalid request body")

    resp = check_ddb_response(
        worker_table.get_item(Key={"id": worker}), f"get worker {worker} by ID"
    )
    if not resp:
        return response(500, "DynamoDB error")

    if "Item" in resp and resp["Item"]:  # The worker exists.
        try:
            _update(worker)
        except Exception as e:
            return response(500, e)

        try:
            job = _get_job(worker)
        except Exception as e:
            if e == NO_JOB_FOUND:
                return NO_JOB
            else:
                return response(500, e)

        return response(200, job, ddb=True)

    try:
        _create(worker)  # The worker does not exist, so create it.
    except Exception as e:
        return response(500, e)
    return NO_JOB


def _create(worker: str) -> None:
    """
    Register a new worker.
    """
    if not check_ddb_response(
        worker_table.put_item(Item={"id": worker, "last_poll": nowstamp()}),
        f"create new worker {worker}",
    ):
        raise Exception("registering worker failed")


def _update(worker: str) -> None:
    """
    Update a worker with the current polling time.
    """
    if not check_ddb_response(
        worker_table.update_item(
            Key={"id": worker},
            UpdateExpression="SET last_poll = :now",
            ExpressionAttributeValues={":now": nowstamp()},
        ),
        f"update worker {worker} last poll time",
    ):
        raise Exception("updating worker failed")


def _get_job(worker: str) -> dict:
    """
    Get a worker's assigned job. Returns None if there is no job.
    """
    resp = check_ddb_response(
        active_job_table.get_item(Key={"worker": worker}),
        f"get active job for {worker}",
    )
    if not resp:
        raise Exception("DynamoDB error: getting active job failed")
    if "Item" not in resp:
        raise NO_JOB_FOUND

    return resp["Item"]
