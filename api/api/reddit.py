import os
import praw

CLIENT_ID = os.getenv("REDDIT_CLIENT_ID")
CLIENT_SECRET = os.getenv("REDDIT_CLIENT_SECRET")
USERNAME = os.getenv("REDDIT_USERNAME")
PASSWORD = os.getenv("REDDIT_PASSWORD")
USER_AGENT = os.getenv("REDDIT_USER_AGENT")

reply = "Video of this play! :)\n{}"


def login():
    """
    Log into Reddit.
    """
    if not (CLIENT_ID and CLIENT_SECRET and USERNAME and PASSWORD):
        print("Reddit environment variables are not set")
        return None

    return praw.Reddit(
        client_id=CLIENT_ID,
        client_secret=CLIENT_SECRET,
        username=USERNAME,
        password=PASSWORD,
        user_agent=USER_AGENT,
    )


def comment_link(job: dict, url: str) -> None:

    """
    Comment on a Reddit post with a video URL.
    """
    client = login()
    if not client:
        return

    post = client.submission(job["id"])
    try:
        return post.reply(reply.format(url))
    except Exception as e:
        print(f"replying to post {job['id']} failed: {e}")
