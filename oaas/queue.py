import random

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger

from . import app
from .clients import Client
from .jobs import Job


def start() -> None:
    scheduler = BackgroundScheduler()
    scheduler.add_job(process, IntervalTrigger(seconds=10))
    scheduler.start()


def process() -> None:
    jobs = Job.get_pending()
    if not jobs:
        app.logger.debug("No jobs pending")
    for job in jobs:
        clients = Client.get_waiting()
        if not clients:
            app.logger.debug("Jobs are pending but no clients are available")
            return
        client = random.choice(clients)
        client.assign(job)
        app.logger.info(f"Assigned job {job.id} to client '{client.id}'")
