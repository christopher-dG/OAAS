import json
import os
import praw
import re

reddit = praw.Reddit(
    user_agent=os.getenv("REDDIT_USER_AGENT"),
    username=os.getenv("REDDIT_USERNAME"),
    password=os.getenv("REDDIT_PASSWORD"),
    client_id=os.getenv("REDDIT_CLIENT_ID"),
    client_secret=os.getenv("REDDIT_CLIENT_SECRET"),
)
subreddit = reddit.subreddit(os.getenv("REDDIT_SUBREDDIT"))
stream = subreddit.stream.submissions()
title = re.compile(".+\|.+-.+\[.+\]")
posts = {}

def next_post():
    """Return the next post to process."""
    p = next(stream)
    while should_skip(p):
        p = next(stream)
    posts[p.id] = p

    return json.dumps({
        "id": p.id,
        "title": p.title,
        "author": p.author.name if p.author else None,
    })


def save_post(id):
    """Save a post by ID."""
    id = id.decode("utf-8")
    if id in posts:
        posts[id].save()
        return True
    return False


def should_skip(p):
    """Determine whether a post should be skipped."""
    if p.saved: return True
    if not title.match(p.title): return True
    return False
