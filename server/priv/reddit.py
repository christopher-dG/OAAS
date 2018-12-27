import json
import os
import praw

reddit = praw.Reddit(
    user_agent=os.getenv("REDDIT_USER_AGENT"),
    username=os.getenv("REDDIT_USERNAME"),
    password=os.getenv("REDDIT_PASSWORD"),
    client_id=os.getenv("REDDIT_CLIENT_ID"),
    client_secret=os.getenv("REDDIT_CLIENT_SECRET"),
)
subreddit = reddit.subreddit(os.getenv("REDDIT_SUBREDDIT"))
stream = subreddit.stream.submissions()
posts = {}


def next_post():
    """Return the next unsaved post."""
    p = next(stream)
    while p.saved:
        p = next(stream)
    posts[p.id] = p

    return json.dumps({
        "id": p.id,
        "title": p.title,
        "author": p.author.name if p.author else None,
    })


def save_post(id):
    """Save a post."""
    if id in posts:
        posts[id].save()
        return True
    return False
