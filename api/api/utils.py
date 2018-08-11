import datetime
import json
from dynamodb_json import json_util as ddb_json
from typing import Optional, Union


def response(
    code: int, body: Union[dict, str, None], quiet: bool = False, ddb: bool = False
) -> dict:
    """
    Return a response suitable for API Gateway.
    """
    if isinstance(body, dict):
        if ddb:
            body = ddb_json.loads(ddb_json.dumps(body))
        body = json.dumps(body)
    elif body is None:
        body = json.dumps(None)
    else:
        if isinstance(body, Exception):
            print("warning: an exception was raised during request handling")
            body = str(body)
        body = json.dumps({"message": body})

    resp = {"statusCode": code, "body": body}
    if not quiet:
        print(f"returning response: {json.dumps(resp, indent=2)}")
    return resp


def nowstamp() -> int:
    """
    Get a millisecond Unix timestamp.
    """
    return round(datetime.datetime.now().timestamp())
