import logging
import os

from typing import Dict, Literal, Optional, Tuple

from flask import Flask, request, session
from flask_sqlalchemy import SQLAlchemy
from flask_socketio import SocketIO, join_room, leave_room

app = Flask(__name__)
app.logger.setLevel(logging.INFO)
app.config["SQLALCHEMY_DATABASE_URI"] = "postgres://"  # Configure DB with environment.
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)
ws = SocketIO(app)

from .clients import Client, ClientStatus  # noqa: E402
from .jobs import Job, JobStatus  # noqa: E402

ADMIN_AUTH_HEADER = os.getenv("HTTP_AUTH_HEADER")
JSON = Tuple[Dict[str, object], int]


@ws.on("connect")
def on_connect() -> Optional[Literal[False]]:
    client = Client.from_key(request.headers.get("Authorization"))
    if not client:
        app.logger.info("Client unauthorized")
        return False
    session["client"] = client.id
    app.logger.info(f"Client '{client.id}' authorized")
    client.update_status(ClientStatus.WAITING)
    join_room(client.id)


@ws.on("disconnect")
def on_disconnect() -> None:
    client = Client.from_id(session.get("client"))
    if client:
        app.logger.info(f"Client '{client.id}' disconnected")
        client.update_status(ClientStatus.OFFLINE)
        leave_room(session.get("room"))


@ws.on("job_done")
def on_job_done(json: Dict[str, int]) -> None:
    job = Job.from_id(json["id"])
    status = JobStatus(json["status"])
    if status not in (JobStatus.FAILED, JobStatus.SUCCEEDED):
        app.logger.warn(f"Job {job.id} received invalid status {status.name}")
        return
    app.logger.info(f"Job {job.id} received status {status.name}")
    job.after(status)
    client = Client.from_id(job.client)
    client.unassign(job, status)


@app.route("/job", methods=["POST"])
def on_job() -> JSON:
    if request.headers.get("Authorization") != ADMIN_AUTH_HEADER:
        app.logger.info("Client unauthorized")
        return {"error": "Unauthorized"}, 403
    job = Job.new(request.json)
    app.logger.info(f"Created job {job.id}")
    return {}, 201
