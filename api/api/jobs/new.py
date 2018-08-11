import json
import random
from boto3.dynamodb.conditions import Attr, Key
from typing import List, Optional

from api.ddb import active_job_table, worker_table
from api.utils import check_ddb_response, nowstamp, response
from api.jobs import PENDING

ONLINE_THRESHOLD = 30  # Seconds.


def handler(event, context):
    """
    Lambda function entrypoint for /jobs/new.
    The request body should be a job to be assigned.
    The job is then assigned to a worker such that when they next request from
    the /poll endpoint, they will be informed of the pending job.
    """
    try:
        body = json.loads(event["body"])
        body["id"]  # Raises KeyError if it's not there.
    except Exception as e:
        print(e)
        print(f"body {event['body']} is invalid")
        return response(400, "invalid request body")

    job_id = body["id"]

    # DynamoDB doesn't allow inserting empty strings.
    body = {k: v if v != "" else None for k, v in body.items()}

    resp = check_ddb_response(
        active_job_table.scan(FilterExpression=Attr("id").eq(job_id)),
        f"get existing job {job_id}",
    )
    if not resp:
        return response(500, f"DynamoDB error: checking for existing job failed")
    if "Items" in resp and resp["Items"]:
        return response(400, f"job {job_id} is already active")

    try:
        worker = _get_worker()
    except Exception as e:
        return response(500, e)

    print(f"assigning job {job_id} to worker {worker}")

    now = nowstamp()
    if not check_ddb_response(
        active_job_table.put_item(
            Item={
                **body,
                "worker": worker,
                "job_status": PENDING,
                "created_at": now,
                "updated_at": now,
            }
        ),
        f"create new job {job_id} for {worker}",
    ):
        return response(500, "DynamoDB error: inserting new job failed")

    return response(200, None)


def _get_worker() -> Optional[str]:
    """
    Find a free worker. If none are available, None is returned.
    We scan through the workers, find an online one without a job,
    then make a choice from those.
    """
    min_stamp = nowstamp() - ONLINE_THRESHOLD
    resp = check_ddb_response(
        worker_table.scan(FilterExpression=Attr("last_poll").gt(min_stamp)),
        "get online workers",
    )
    if not resp or "Items" not in resp or not resp["Items"]:
        raise Exception("no workers are available (all offline)")

    eligible = [i["id"] for i in resp["Items"]]

    # TODO: Do we have to scan here?
    resp = check_ddb_response(active_job_table.scan(), "get active jobs")
    if not resp:
        raise Exception("DynamoDB error: getting active jobs failed")

    busy = [i["worker"] for i in resp["Items"]]
    eligible = [w for w in eligible if w not in busy]
    if not eligible:
        raise Exception("no workers are available (all busy)")

    return _choose(eligible)


def _choose(workers: List[dict]) -> dict:
    """
    Make a choice from a list of eligible workers.
    TODO: LRU.
    """
    return random.choice(workers)
