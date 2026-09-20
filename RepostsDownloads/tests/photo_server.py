import base64
import http.server
import sys
import time
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aK1cAAAAASUVORK5CYII=')
class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_GET(self):
        try:
            if self.path == '/redirect':
                self.send_response(302); self.send_header('Location', 'https://example.com/not-a-photo'); self.end_headers(); return
            if self.path == '/slow': time.sleep(1)
            self.send_response(404 if self.path == '/missing' else 200)
            self.send_header('Content-Type', 'text/html' if self.path == '/html' else 'image/png')
            data = b'not a real image' if self.path == '/fake' else PNG
            self.send_header('Content-Length', str(33 * 1024 * 1024 if self.path == '/large' else len(data)))
            self.end_headers()
            if self.path != '/large': self.wfile.write(data)
        except (BrokenPipeError, ConnectionResetError): pass
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
with open(sys.argv[1], 'w') as file: file.write(str(server.server_port))
server.serve_forever()
