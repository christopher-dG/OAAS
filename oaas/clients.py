from __future__ import annotations

import os
import random

from datetime import datetime
from enum import IntEnum
from typing import List, Optional
from uuid import uuid4

from . import db, ws
from .jobs import Job, JobStatus

ClientStatus = IntEnum("ClientStatus", "OFFLINE WAITING BUSY")

with open(os.getenv("WORD_LIST", "/usr/share/dict/words")) as f:
    WORDS = {line.strip().lower() for line in f.readlines() if "'" not in line}


def _make_id() -> str:
    return "-".join(random.sample(WORDS, 3))


def _make_key() -> str:
    return str(uuid4())


class Client(db.Model):
    id = db.Column(db.String(128), primary_key=True, default=_make_id)
    key = db.Column(
        db.String(64), unique=True, nullable=False, index=True, default=_make_key
    )
    status = db.Column(
        db.Integer, nullable=False, index=True, default=ClientStatus.OFFLINE.value
    )
    job = db.Column(db.Integer, db.ForeignKey("job.id"))
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    @staticmethod
    def from_id(id: str) -> Optional[Client]:
        return Client.query.get(id)

    @staticmethod
    def from_key(key: str) -> Optional[Client]:
        return Client.query.filter_by(key=key).first()

    @staticmethod
    def get_waiting() -> List[Client]:
        return Client.query.filter_by(status=ClientStatus.WAITING).all()

    def assign(self, job: Job, commit: bool = True) -> None:
        self.job = job.id
        self.update_status(ClientStatus.BUSY, commit=False)
        job.client = self.id
        job.update_status(JobStatus.ASSIGNED, commit=False)
        db.session.add(self)
        db.session.add(job)
        if commit:
            db.session.commit()
        ws.emit("new_job", {"job": job.as_dict()}, room=self.id)

    def unassign(self, job: Job, status: JobStatus, commit: bool = True) -> None:
        self.status = ClientStatus.WAITING
        self.job = None
        job.status = status
        job.client = None
        db.session.add(self)
        db.session.add(job)
        if commit:
            db.session.commit()

    def update_status(self, status: ClientStatus, commit: bool = True) -> None:
        self.status = status
        db.session.add(self)
        if commit:
            db.session.commit()
