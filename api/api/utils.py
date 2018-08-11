import datetime
import json
from dynamodb_json import json_util as ddb_json
from typing import Optional, Union


def response(
    code: int, body: Union[dict, str], quiet: bool = False, ddb: bool = False
) -> dict:
    """
    Return a response suitable for API Gateway.
    """
    if isinstance(body, dict):
        if ddb:
            body = ddb_json.loads(ddb_json.dumps(body))
        body = json.dumps(body)
    else:
        if isinstance(body, Exception):
            print("warning: an exception was raised during request handling")
            body = str(body)
        body = json.dumps({"message": body})

    resp = {"statusCode": code, "body": body}
    if not quiet:
        print(f"returning response: {json.dumps(resp, indent=2)}")
    return resp


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

    print(f"[{ctx}] response:\n{ddb_json.dumps(resp, indent=2)}")
    return resp


def nowstamp() -> int:
    """
    Get a millisecond Unix timestamp.
    """
    return round(datetime.datetime.now().timestamp())
