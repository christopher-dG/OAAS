import json
from boto3.dynamodb.conditions import Attr
from typing import Optional

from api import ddb
from api.utils import nowstamp, response

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

    try:
        ddb.get_worker(worker)
        exists = True
    except Exception as e:
        if not ddb.is_not_found(e):
            return response(500, e)
        exists = False

    if exists:
        try:
            ddb.update_worker(worker)
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

    # The worker does not exist.
    try:
        ddb.create_worker(worker)
    except Exception as e:
        return response(500, e)
    return NO_JOB


def _get_job(worker: str) -> dict:
    """
    Get a worker's assigned job. Returns None if there is no job.
    """
    try:
        job = ddb.get_active_job(worker)
    except Exception as e:
        if ddb.is_not_found(e):
            raise NO_JOB_FOUND
        raise e
    return job
