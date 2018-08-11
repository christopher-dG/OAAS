from api.utils import nowstamp
from api.jobs import THRESHOLDS


def is_online(worker: dict) -> bool:
    """
    Determine whether or not a worker is online.
    """
    return nowstamp() - THRESHOLDS["ONLINE"] < worker["last_poll"]


def is_stalled(job: dict) -> bool:
    """
    Determine whether or not a job is stalled.
    """
    return nowstamp() - THRESHOLDS[job["job_status"]] > job["last_update"]
