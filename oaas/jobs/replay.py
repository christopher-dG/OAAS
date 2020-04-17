from typing import Dict

from . import Job, JobType


class RecordReplayJob(Job):
    def __init__(self, data: Dict[str, object]) -> None:
        super().__init__(type=JobType.RECORD_REPLAY, data=data)

    def before(self) -> None:
        # TODO: Add the upload URL.
        pass
