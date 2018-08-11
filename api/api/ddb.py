import boto3
from boto3.dynamodb.conditions import Attr, Key
from dynamodb_json import json_util as ddb_json
from typing import List, Optional

from api.utils import nowstamp
from api.jobs import PENDING, SUCCEEDED, FAILED, THRESHOLDS

_ddb = boto3.resource("dynamodb")
_active = _ddb.Table("replay-bot-jobs-active")
_backlogged = _ddb.Table("replay-bot-jobs-backlogged")
_completed = _ddb.Table("replay-bot-jobs-completed")
_workers = _ddb.Table("replay-bot-workers")


def is_not_found(e: Exception) -> bool:
    """
    Determine whether or not an exception is due to a resource not being found.
    """
    return e.args[0].endswith("not found")


def get_active_job(worker: str) -> dict:
    """
    Get an active job by worker ID.
    """
    print(f"getting job for {worker}")

    resp = _check(_active.get_item(Key={"worker": worker}), "get active job by worker")
    if not resp:
        raise _ddb_err("get active job failed")
    if "Item" not in resp or not resp["Item"]:
        raise Exception("active job not found")

    print(f"retrieved job")
    return resp["Item"]


def get_active_jobs() -> List[dict]:
    """
    Get all active jobs.
    """
    print("getting all active jobs")

    resp = _check(_active.scan(), "get active jobs")
    if not resp:
        raise _ddb_err("get active jobs failed")

    print("retrieved active jobs")
    return resp.get("Items", [])


def active_job_exists(id: str) -> bool:
    """
    Check if a job is active by ID.
    """
    print(f"checking for active job {id}")

    resp = _check(_active.scan(FilterExpression=Attr("id").eq(id)), "scan active jobs")
    if not resp:
        raise _ddb_err("scan active jobs failed")
    exists = bool(resp.get("Items"))

    print(f"exists = {exists}")
    return exists


def update_active_job(worker: str, status: int) -> None:
    """
    Update an active job's status.
    """
    print(f"updating active job by {worker} to {status}")

    if not _check(
        _active.update_item(
            Key={"worker": worker},
            UpdateExpression="SET job_status = :status, updated_at = :now",
            ExpressionAttributeValues={":status": status, ":now": nowstamp()},
        ),
        "update job  active -> active",
    ):
        raise _ddb_err("update active job failed")

    print(f"updated job status")


def assign_job(job: dict, worker: str) -> None:
    """
    Assign a job to a worker.
    """
    print(f"assigning job {job} to worker {worker}")

    now = nowstamp()
    if not _check(
        _active.put_item(
            Item={
                **job,
                "worker": worker,
                "job_status": PENDING,
                "created_at": now,
                "updated_at": now,
            }
        ),
        f"create new job",
    ):
        raise _ddb_err("create new active job failed")

    print(f"assigned job")


def move_active_completed(job: dict, success: bool) -> None:
    """
    Move an active job to completed.
    """
    print(f"moving job {job} to completed (job success = {success}")

    if not _check(
        _completed.put_item(
            Item={
                **job,
                "job_status": SUCCEEDED if success else FAILED,
                "updated_at": nowstamp(),
            }
        ),
        "copy job active -> completed",
    ):
        raise _ddb_err("update active -> completed failed")

    if not _check(
        _active.delete_item(Key={"worker": job["worker"]}), f"delete active job"
    ):
        raise _ddb_err("delete active job failed")

    print("moved job to completed")


def get_worker(id: str) -> dict:
    """
    Get a worker by ID.
    """
    print(f"getting worker {id}")

    resp = _check(_workers.get_item(Key={"id": id}), "get worker by ID")
    if not resp:
        raise _ddb_err("get worker by ID failed")
    if "Item" not in resp or not resp["Item"]:
        raise Exception("worker not found")

    print(f"retrieved worker")
    return resp["Item"]


def create_worker(id: str) -> None:
    """
    Create and store a new worker.
    """
    print(f"creating worker {id}")

    if not _check(
        _workers.put_item(Item={"id": id, "last_poll": nowstamp()}),
        f"create new worker",
    ):
        raise _ddb_err("create new worker failed")

    print("created worker")


def update_worker(id: str) -> None:
    """
    Update a worker's last poll time.
    """
    print(f"updating worker {id}")

    if not _check(
        _workers.update_item(
            Key={"id": id},
            UpdateExpression="SET last_poll = :now",
            ExpressionAttributeValues={":now": nowstamp()},
        ),
        f"update worker",
    ):
        raise _ddb_err("update worker failed")

    print("updated worker")


def get_workers() -> List[dict]:
    """
    Get all workers.
    """
    print("getting all workers")

    resp = _check(_workers.scan(), "scan workers")
    if not resp:
        raise _ddb_err("scan workers failed")

    print("retrieved workers")
    return resp.get("Items", [])


def get_online_workers() -> List[dict]:
    """
    Get all workers who are currently online.
    """
    print("getting online workers")

    min_stamp = nowstamp() - THRESHOLDS["ONLINE"]
    resp = _check(
        _workers.scan(FilterExpression=Attr("last_poll").gt(min_stamp)),
        "get recent workers workers",
    )
    if not resp:
        raise _ddb_err("get recent jobs failed")

    print("retrieved online workers")
    return resp.get("Items", [])


def get_backlogged() -> List[dict]:
    """
    Get all backlogged jobs.
    """
    print("getting backlogged jobs")

    resp = _check(_backlogged.scan(), "scan backlogged jobs")
    if not resp:
        raise _ddb_err("scan backlogged jobs failed")

    print("retrieved backlog")
    return resp.get("Items", [])


def backlog_job(job: dict) -> None:
    """
    Add a job to the backlog.
    """
    print(f"inserting job {job['id']} into backlog")

    if not _check(
        _backlogged.put_item(Item={**job, "created_at": nowstamp(), "updated_at": now}),
        f"insert new job {job['id']} into backlog",
    ):
        raise _ddb_err("insert new backlogged job failed")

    print("inserted job into backlog")


def _check(resp: dict, ctx: str) -> Optional[dict]:
    """
    Check the status code of a DynamoDB response.
    The response is returned only if the request was successful.
    """
    if "ResponseMetadata" not in resp:
        print("response is missing 'ResponseMetadata' key")
        return None
    if "HTTPStatusCode" not in resp["ResponseMetadata"]:
        print("response metadata is missing 'HTTPStatusCode' key")
        return None

    code = resp["ResponseMetadata"]["HTTPStatusCode"]
    if code not in range(200, 300):
        print(f"[{ctx}] DynamoDB request returned {code}")
        return None

    print(f"[{ctx}] response:\n{ddb_json.dumps(resp, indent=2)}")
    return resp


def _ddb_err(msg: str) -> Exception:
    """
    Create an Exception caused by DynamoDB.
    """
    return Exception(f"DynamoDB error: {msg}")
