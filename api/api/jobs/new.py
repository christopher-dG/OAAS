import json
import random
from typing import List, Optional

from api import ddb
from api.utils import nowstamp, response

ALL_BUSY = Exception("no workers are available (all busy)")
ALL_OFFLINE = Exception("no workers are available (all offline)")


def handler(event, context):
    """
    Lambda function entrypoint for /jobs/new.
    The request body should be a job to be assigned.
    The job is then assigned to a worker such that when they next request from
    the /poll endpoint, they will be informed of the pending job.
    """
    try:
        job = json.loads(event["body"])
        job_id = job["id"]
    except Exception as e:
        print(e)
        print(f"body {event['body']} is invalid")
        return response(400, "invalid request body")

    # DynamoDB doesn't allow inserting empty strings.
    job = {k: v if v != "" else None for k, v in job.items()}

    try:
        exists = ddb.active_job_exists(job_id)
    except Exception as e:
        return response(500, e)

    if exists:
        return response(400, "job is already active")

    try:
        worker = _get_worker()
    except Exception as e:
        if e in [ALL_BUSY, ALL_OFFLINE]:
            try:
                ddb.backlog_job(job)
            except Exception as e:
                return response(500, e)
            return response(200, "backlogged")
        return response(500, e)

    print(f"assigning job {job_id} to worker {worker}")

    try:
        ddb.assign_job(job, worker)
    except Exception as e:
        return response(500, e)
    return response(200, None)


def _get_worker() -> str:
    """
    Find a free worker (by ID). If none are available an exception is raised.
    """
    online = ddb.get_online_workers()
    if not online:
        raise ALL_OFFLINE

    busy = [j["worker"] for j in ddb.get_active_jobs()]
    eligible = [w["id"] for w in online if w["id"] not in busy]

    if not eligible:
        raise ALL_BUSY

    return _choose(eligible)


def _choose(workers: List[dict]) -> dict:
    """
    Make a choice from a list of eligible workers. TODO: LRU.
    """
    return random.choice(workers)
