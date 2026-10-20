"""Persistent notes demo with SQLite fallback and a prepared PostgreSQL stage."""
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
from database import Database

DATABASE = Database()

PAGE = '''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>From Sovereignty to Liberty</title><link rel="stylesheet" href="/style.css"></head><body><main><div class="eyebrow">THE PORTABLE PLATFORM DEMO</div><h1>From Sovereignty<br>to Liberty.</h1><p class="intro">One application. The same Kubernetes platform. A cloud you can leave.</p><section><div class="section-title"><h2>Leave a note</h2><span id="status">Connecting…</span></div><p>Your notes survive an application restart.</p><form id="form"><label for="message">Message</label><div class="row"><input id="message" name="message" maxlength="200" placeholder="A small piece of state to take with you" required><button>Save note</button></div></form><p id="feedback" role="status"></p><ul id="notes"></ul></section><footer>A shared application, reconciled by Flux.</footer></main><script src="/app.js"></script></body></html>'''
CSS = '''*{box-sizing:border-box}body{margin:0;background:#111b27;color:#eef1e7;font-family:system-ui,sans-serif}main{max-width:850px;margin:70px auto;padding:0 28px}.eyebrow{color:#a2c788;font-size:12px;letter-spacing:.19em;font-weight:700}h1{font-size:clamp(42px,7vw,74px);letter-spacing:-.05em;line-height:1.06;margin:23px 0}.intro{color:#abb9c5;font-size:20px;line-height:1.6;max-width:600px}section{margin-top:42px;padding:27px;border:1px solid #354351;border-radius:18px;background:#182635}.section-title{display:flex;align-items:center;justify-content:space-between;gap:15px}h2{margin:0;font-size:24px}#status{color:#a2c788;font-size:13px}section p,footer{color:#abb9c5}label{font-size:13px;display:block;margin-bottom:9px}.row{display:flex;gap:10px}input{width:100%;background:#111b27;border:1px solid #435261;border-radius:8px;padding:14px;color:#eef1e7;font:inherit}button{white-space:nowrap;background:#b4d792;color:#162414;font-weight:700;border:0;border-radius:8px;padding:14px 21px;cursor:pointer}button:disabled{opacity:.55;cursor:wait}ul{list-style:none;padding:0;margin:20px 0 0}li{padding:17px 0;border-top:1px solid #354351;overflow-wrap:anywhere}time{display:block;font-size:12px;color:#8194a4;margin-top:6px}#feedback{min-height:20px;font-size:13px}footer{font-size:13px;margin:25px 0}@media(max-width:580px){main{margin-top:40px}.row{flex-direction:column}.section-title{align-items:flex-start;flex-direction:column}}'''
JS = '''const list=document.querySelector('#notes'),form=document.querySelector('#form'),button=form.querySelector('button'),feedback=document.querySelector('#feedback');async function refresh(){const response=await fetch('/api/notes');if(!response.ok)throw Error('Could not load notes');const data=await response.json();list.replaceChildren();for(const note of data.notes){const li=document.createElement('li'),text=document.createElement('span'),time=document.createElement('time');text.textContent=note.message;time.textContent=new Date(note.created).toLocaleString();li.append(text,time);list.append(li)}document.querySelector('#status').textContent='Online · '+data.notes.length+' notes'}form.addEventListener('submit',async event=>{event.preventDefault();button.disabled=true;feedback.textContent='Saving…';try{const response=await fetch('/api/notes',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({message:form.message.value})});if(!response.ok)throw Error('Could not save note');form.reset();await refresh();feedback.textContent='Note saved.'}catch(error){feedback.textContent=error.message}finally{button.disabled=false}});refresh().catch(()=>{document.querySelector('#status').textContent='Unavailable';feedback.textContent='The application is starting. Refresh in a moment.'});'''

class Handler(BaseHTTPRequestHandler):
    def respond(self, status, body, content_type='application/json'):
        payload = json.dumps(body).encode() if content_type == 'application/json' else body.encode()
        self.send_response(status)
        self.send_header('Content-Type', content_type + '; charset=utf-8')
        self.send_header('Content-Length', str(len(payload)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Content-Security-Policy', "default-src 'self'; frame-ancestors 'none'; base-uri 'none'")
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        if self.path == '/healthz':
            try:
                DATABASE.health()
            except Exception:
                return self.respond(503, {'status': 'unavailable'})
            return self.respond(200, {'status': 'ok', 'backend': DATABASE.backend})
        if self.path == '/':
            return self.respond(200, PAGE, 'text/html')
        if self.path == '/style.css':
            return self.respond(200, CSS, 'text/css')
        if self.path == '/app.js':
            return self.respond(200, JS, 'text/javascript')
        if self.path == '/api/notes':
            rows = DATABASE.notes()
            return self.respond(200, {'notes': [{'id': row[0], 'message': row[1], 'created': row[2]} for row in rows]})
        self.respond(404, {'error': 'Not found'})

    def do_POST(self):
        if self.path != '/api/notes':
            return self.respond(404, {'error': 'Not found'})
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 2048:
                return self.respond(413, {'error': 'Invalid request size'})
            message = json.loads(self.rfile.read(length)).get('message')
            if not isinstance(message, str) or not 0 < len(message.strip()) <= 200:
                return self.respond(400, {'error': 'Provide a message of 1–200 characters'})
        except (ValueError, AttributeError, UnicodeDecodeError):
            return self.respond(400, {'error': 'Invalid JSON'})
        created = datetime.now(timezone.utc).isoformat()
        identifier = DATABASE.add(message.strip(), created)
        self.respond(201, {'id': identifier, 'message': message.strip(), 'created': created})

if __name__ == '__main__':
    ThreadingHTTPServer(('0.0.0.0', int(os.environ.get('PORT', '8080'))), Handler).serve_forever()
