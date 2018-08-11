PENDING = 0  # Job has not been acknowledged.
ACKNOWLEDGED = 1  # Worker has acknowledged the job.
RECORDING = 2  # Worker has begun recording the play.
UPLOADING = 3  # Worker has begun uploading the play.
SUCCEEDED = 4  # Job is complete and successful.
FAILED = 5  # Job is complete and failed.

# Number of seconds per active status above which a worker is considered inactive.
THRESHOLDS = {
    "ONLINE": 30,
    PENDING: 30,
    ACKNOWLEDGED: 60,
    RECORDING: 60 * 30,
    UPLOADING: 60 * 60,
}

from api.jobs import new
from api.jobs import cleanup
from api.jobs import status
