PENDING = 0  # Job has not been acknowledged.
ACKNOWLEDGED = 1  # Worker has acknowledged the job.
RECORDING = 2  # Worker has begun recording the play.
UPLOADING = 3  # Worker has begun uploading the play.
SUCCEEDED = 4  # Job is complete and successful.
FAILED = 5  # Job is complete and failed.

from api.jobs import new
from api.jobs import status
