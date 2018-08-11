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
    cleanup_active()
    process_backlog()


def cleanup_active() -> None:
    try:
        active = ddb.get_active_jobs()
    except Exception as e:
        print(e)
        return

    if not active:
        print("no jobs to clean up")
        return

    try:
        workers = {w["id"]: w for w in ddb.get_workers()}
    except Exception as e:
        print(e)
        return

    for job in jobs:
        worker_id = job["worker"]
        worker = workers[worker_id]
        job_id = job["id"]

        if not is_online(worker):
            print(f"worker {worker_id} for job {job_id} is offline")
            try:
                ddb.move_active_completed(job, False)
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
            except Exception as e:
                print(e)


def process_backlog() -> None:
    """
    Go through the backlog and assign free workers to jobs.
    """
    try:
        backlog = ddb.get_backlogged()
    except Exception as e:
        print(e)
        return

    if not backlog:
        print("no backlog to process")
        return

    backlog = sorted(backlog, key=lambda j: j["created_at"], reverse=True)

    try:
        jobs = ddb.get_active_jobs()
    except Exception as e:
        print(e)
        return

    try:
        workers = ddb.get_workers()
    except Exception as e:
        print(e)
        return

    if not workers:
        print("no workers found")
        return

    active = [j["worker"] for j in jobs]
    workers = [w for w in workers if is_online(w) and w["id"] not in active]

    for w in workers:
        if not backlogged:
            break

        try:
            job = backlog.pop()
            assign_job(job, w)
        except Exception as e:
            print(e)
            backlog.append(job)
