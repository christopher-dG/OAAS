from __future__ import annotations

from datetime import datetime
from enum import IntEnum
from typing import Dict, List, Optional

from .. import db


JobType = IntEnum("JobType", "RECORD_REPLAY")
JobStatus = IntEnum("JobStatus", "PENDING ASSIGNED IN_PROGRESS FAILED SUCCEEDED")


class Job(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    type = db.Column(db.Integer, nullable=False)
    status = db.Column(db.Integer, nullable=False, default=JobStatus.PENDING.value)
    client = db.Column(db.String(128), db.ForeignKey("client.id"))
    data = db.Column(db.JSON)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(
        db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    @staticmethod
    def from_id(id: int) -> Optional[Job]:
        return Job.query.get(id)

    @staticmethod
    def get_pending() -> List[Job]:
        return Job.query.filter_by(status=JobStatus.PENDING).all()

    def update_status(self, status: JobStatus, commit: bool = True) -> None:
        self.status = status
        db.session.add(self)
        if commit:
            db.session.commit()

    def as_dict(self) -> Dict[str, object]:
        return {
            "id": self.id,
            "type": self.type,
            "data": self.data,
        }
