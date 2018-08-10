import json
import random
from boto3.dynamodb.conditions import Attr, Key
from typing import List, Optional

from api.ddb import active_job_table, worker_table
from api.utils import check_ddb_response, nowstamp
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
        return {"statusCode": 400}

    worker = _get_worker()
    if not worker:
        return {"statusCode": 500}

    print(f"assigning job {body['id']} to worker {worker}")

    now = nowstamp()
    if not bool(
        check_ddb_response(
            active_job_table.put_item(
                Item={
                    **body,
                    "worker": worker,
                    "job_status": PENDING,
                    "created_at": now,
                    "updated_at": now,
                }
            ),
            f"create new job {body['id']} for {worker}",
        )
    ):
        return {"statusCode": 500}

    return {"statusCode": 200}


def _get_worker() -> Optional[str]:
    """
    Find a free worker. If none are available, None is returned.
    We scan through the workers, find an online one without a job,
    then make a choice from those.
    """
    min_stamp = int(nowstamp()) - ONLINE_THRESHOLD
    resp = check_ddb_response(
        worker_table.scan(FilterExpression=Attr("last_poll").gt(min_stamp)),
        "get online workers",
    )
    if not resp or "Items" not in resp or not resp["Items"]:
        print("no workers are available (all offline)")
        return None

    eligible = [i["id"] for i in resp["Items"]]

    # TODO: Do we have to scan here?
    resp = check_ddb_response(active_job_table.scan(), "get active jobs")
    if not resp:
        return None

    busy = [i["worker"] for i in resp["Items"]]
    eligible = [w for w in eligible if w not in busy]
    if not eligible:
        print("no workers are available (all busy)")
        return None

    return _choose(eligible)


def _choose(workers: List[dict]) -> dict:
    """
    Make a choice from a list of eligible workers.
    TODO: LRU.
    """
    return random.choice(workers)
