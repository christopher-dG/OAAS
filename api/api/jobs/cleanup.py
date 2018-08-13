from api import ddb
from api.utils import nowstamp, response
from api.jobs.utils import is_online, is_stalled


def handler(event, context):
    """
    Lambda function entrypoint for job maintentance.
    This function doesn't run off HTTP requests, but a timer instead.
    It moves jobs that have been sitting too long or whose workers are offline
    to the completed table with failed status.
    It also moves jobs from the backlog onto unused workers.
    """
    print(f"cleaned up {cleanup_active()} active jobs")
    print(f"started {process_backlog()} backlogged jobs")


def cleanup_active() -> int:
    """
    Cleans up active jobs whose workers are offline or stalled.
    Returns the number of cleaned up jobs.
    """
    try:
        active = ddb.get_active_jobs()
    except Exception as e:
        print(e)
        return 0

    if not active:
        print("no jobs to clean up")
        return 0

    try:
        workers = {w["id"]: w for w in ddb.get_workers()}
    except Exception as e:
        print(e)
        return 0

    if not any(is_online(w) for w in workers.values()):
        print("no workers online, nothing to do")
        return 0

    cleaned = 0
    for job in active:
        worker_id = job["worker"]
        worker = workers[worker_id]
        job_id = job["id"]

        if not is_online(worker):
            print(f"worker {worker_id} for job {job_id} is offline")
            try:
                ddb.move_active_completed(job, False)
                cleaned += 1
            except Exception as e:
                print(e)
            else:
                continue

        if is_stalled(job):
            print(
                f"worker {worker_id} for job {job_id} is stalled at status {job['status']}"
            )
            try:
                move_active_completed(job, False)
                cleaned += 1
            except Exception as e:
                print(e)

    return cleaned


def process_backlog() -> int:
    """
    Go through the backlog and assign free workers to jobs.
    Returns the number of assigned jobs.
    """
    try:
        backlog = ddb.get_backlogged()
    except Exception as e:
        print(e)
        return 0

    if not backlog:
        print("no backlog to process")
        return 0

    backlog = sorted(backlog, key=lambda j: j["created_at"], reverse=True)

    try:
        jobs = ddb.get_active_jobs()
    except Exception as e:
        print(e)
        return 0

    try:
        workers = ddb.get_workers()
    except Exception as e:
        print(e)
        return 0

    if not any(is_online(w) for w in workers):
        print("no workers online, nothing to do")
        return 0

    active = [j["worker"] for j in jobs]
    available = [w["id"] for w in workers if is_online(w) and w["id"] not in active]

    assigned = 0
    for w in available:
        if not backlog:
            break

        job = backlog.pop()

        try:
            ddb.assign_job(job, w)
            assigned += 1
        except Exception as e:
            print(e)
            backlog.append(job)

    return assigned
