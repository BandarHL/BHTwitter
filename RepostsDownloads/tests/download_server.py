import http.server
import sys
import time

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_GET(self):
        try:
            if self.path == '/bad':
                payload = b'{"error":"forbidden"}'
                self.send_response(403)
                self.send_header('Content-Type', 'application/json')
            else:
                payload = b'test-video'
                self.send_response(200)
                self.send_header('Content-Type', 'video/mp4')
            if self.path in ('/slow', '/stall'):
                self.send_header('Content-Length', '100')
                self.end_headers()
                self.wfile.write(b'a')
                self.wfile.flush()
                if self.path == '/stall':
                    time.sleep(5)
                    self.wfile.write(b'b' * 99)
                else:
                    for _ in range(99):
                        time.sleep(0.05)
                        self.wfile.write(b'b')
                        self.wfile.flush()
            else:
                self.send_header('Content-Length', str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
        except (BrokenPipeError, ConnectionResetError):
            pass

server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
with open(sys.argv[1], 'w') as output:
    output.write(str(server.server_port))
server.serve_forever()
