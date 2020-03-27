from . import app, queue, ws

queue.start()
ws.run(app)
