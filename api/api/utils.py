import datetime
from typing import Optional


def check_ddb_response(resp: dict, ctx: str) -> Optional[dict]:
    """
    Check the status code of a DynamoDB response.
    The response is returned only if the request was successful.
    """
    if "ResponseMetadata" not in resp:
        print("response is missing 'ResponseMetadata' key")
        return None
    if "HTTPStatusCode" not in resp["ResponseMetadata"]:
        print("response metadata is missing 'HTTPStatusCode' key")
        return None

    code = resp["ResponseMetadata"]["HTTPStatusCode"]
    if code not in range(200, 300):
        print(f"[{ctx}] DynamoDB request returned {code}")
        return None

    return resp


def nowstamp() -> str:
    """
    Get a millisecond Unix timestamp.
    """
    return round(datetime.datetime.now().timestamp())
