#!/usr/bin/env python3
"""Local HTTP fixtures for the production share-image streaming receiver."""
import base64
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import struct
import sys
import time
import zlib

PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6O1sAAAAASUVORK5CYII=')

def oversized_pixels():
    payload = bytearray(PNG)
    payload[16:24] = struct.pack('>II', 9000, 4000)
    payload[29:33] = struct.pack('>I', zlib.crc32(payload[12:29]) & 0xffffffff)
    return bytes(payload)

class Handler(BaseHTTPRequestHandler):
    protocol_version = 'HTTP/1.1'
    def log_message(self, *_):
        pass
    def do_GET(self):
        path = self.path.split('?')[0]
        try:
            if path.startswith('/redirect'):
                self.send_response(302)
                target = '/image' if path == '/redirect' else ('/redirect-loop' if path == '/redirect-loop' else 'http://127.0.0.1:1/forbidden')
                self.send_header('Location', target)
                self.send_header('Content-Length', '0')
                self.end_headers()
                return
            status = 404 if path == '/error-image' else 200
            content_type = 'text/plain' if path == '/wrong-mime' else 'image/png'
            body = oversized_pixels() if path == '/pixels' else PNG
            if path == '/padded':
                body += b'\0' * (7 * 1024 * 1024 - len(body))
            self.send_response(status)
            self.send_header('Content-Type', content_type)
            if path == '/declared-large':
                self.send_header('Content-Length', str(13 * 1024 * 1024))
            elif path == '/chunked-large':
                self.send_header('Transfer-Encoding', 'chunked')
            elif path != '/unknown':
                self.send_header('Content-Length', str(len(body)))
            else:
                self.send_header('Connection', 'close')
                self.close_connection = True
            self.end_headers()
            if path == '/declared-large':
                self.wfile.write(PNG + b'\0' * 1024)
                self.wfile.flush()
                return
            if path == '/slow':
                time.sleep(0.25)
            if path == '/chunked-large':
                chunk = b'x' * (512 * 1024)
                for _ in range(30):
                    self.wfile.write(f'{len(chunk):x}\r\n'.encode() + chunk + b'\r\n')
                    self.wfile.flush()
                    time.sleep(0.003)
                self.wfile.write(b'0\r\n\r\n')
            else:
                for offset in range(0, len(body), 65536):
                    self.wfile.write(body[offset:offset + 65536])
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError):
            pass

server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
with open(sys.argv[1], 'w') as output:
    output.write(str(server.server_port))
server.serve_forever()
