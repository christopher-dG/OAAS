import json
from boto3.dynamodb.conditions import Attr
from typing import Optional

from api.ddb import active_job_table, worker_table
from api.utils import check_ddb_response, nowstamp


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
        return {"statusCode": 400}

    resp = check_ddb_response(
        worker_table.get_item(Key={"id": worker}), f"get worker {worker} by ID"
    )
    if not resp:
        return {"statusCode": 500}

    if "Item" in resp and resp["Item"]:  # The worker exists.
        if not _update(worker):
            return {"statusCode": 500}
        job = _get_job(worker)
        if job:
            return {"statusCode": 200, "message": {"body": job}}
        else:  # No work to be done.
            return {"statusCode": 204}

    if _create(worker):  # The worker does not exist, so create it.
        return {"statusCode": 204}

    return {"statusCode": 500}


def _create(worker: str) -> bool:
    """
    Register a new worker.
    """
    return bool(
        check_ddb_response(
            worker_table.put_item(Item={"id": worker, "last_poll": nowstamp()}),
            f"create new worker {worker}",
        )
    )


def _update(worker: str) -> bool:
    """
    Update a worker with the current polling time.
    """
    return bool(
        check_ddb_response(
            worker_table.update_item(
                Key={"id": worker},
                UpdateExpression="SET last_poll = :now",
                ExpressionAttributeValues={":now": nowstamp()},
            ),
            f"update worker {worker} last poll time",
        )
    )


def _get_job(worker: str) -> Optional[dict]:
    """
    Get a worker's assigned job. Returns None if there is no job.
    """
    resp = check_ddb_response(
        active_job_table.get_item(Key={"worker": worker}),
        f"get active job for {worker}",
    )
    if not resp or "Item" not in resp:
        return None

    if "job" not in resp["Item"]:
        print(f"job {job['id']} is missing key 'job'")

    return resp["Item"]["job"]
