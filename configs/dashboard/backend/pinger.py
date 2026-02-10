import sys
print("Starting pinger.py script...", file=sys.stdout, flush=True)
import asyncio
import websockets
import json
import urllib.request
import urllib.error
import ssl
import http.cookiejar
import sys

# Constants
PORT = 8080

# (Global SSL context is fine to reuse as it's just config)
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

async def check_url(url):
    print(f"Checking {url}...", file=sys.stderr, flush=True)
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'K8s-Dashboard-Pinger/1.0'})

        # Run synchronous urllib in a thread executor to be async-friendly
        loop = asyncio.get_running_loop()
        resp_code = await loop.run_in_executor(None, lambda: perform_request(req))

        print(f"Checked {url}: {resp_code}", file=sys.stderr, flush=True)

        # 200-299 is success
        if 200 <= resp_code < 300:
            return True
        else:
            return False

    except Exception as e:
        print(f"Error checking {url}: {e}", file=sys.stderr, flush=True)
        # Check for our custom "success error codes" if perform_request raises them?
        # Actually perform_request will catch and return code.
        return False

def perform_request(req):
    try:
        # Create fresh CookieJar and Opener for EVERY request to avoid stale session issues
        cj = http.cookiejar.CookieJar()
        opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(cj),
            urllib.request.HTTPSHandler(context=ctx),
            urllib.request.HTTPHandler()
        )

        print(f"DEBUG: Opening {req.full_url}...", file=sys.stdout, flush=True)
        with opener.open(req, timeout=5) as resp:
            print(f"DEBUG: Opened {req.full_url} - Code {resp.getcode()}", file=sys.stdout, flush=True)
            return resp.getcode()
    except urllib.error.HTTPError as e:
        # Treat 4xx/5xx/3xx as "Online" (technically reachable)
        # User accepted 401/403 previously.
        # But wait, user requested stricter rules "only 200-299" in Step 583.
        # "apenas considere verde se der statuscode >=200 e <299"
        # So we return the code and let the caller decide.
        return e.code
    except Exception as e:
        raise e

async def handler(websocket):
    print("Client connected", file=sys.stderr)
    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                url = data.get('url')
                app_name = data.get('name')

                if url:
                    # Launch task to check URL
                    asyncio.create_task(process_check(websocket, app_name, url))
            except json.JSONDecodeError:
                pass
    except websockets.ConnectionClosed:
        print("Client disconnected", file=sys.stderr)

async def process_check(websocket, app_name, url):
    is_up = await check_url(url)
    response = {
        'name': app_name,
        'url': url,
        'status': 'up' if is_up else 'down'
    }
    print(f"Sending {app_name} ({url}) status: {response['status']}", file=sys.stdout, flush=True)
    try:
        await websocket.send(json.dumps(response))
    except websockets.ConnectionClosed:
        pass

async def main():
    print(f"WebSocket Pinger serving at port {PORT}", file=sys.stderr)
    async with websockets.serve(handler, "0.0.0.0", PORT):
        await asyncio.get_running_loop().create_future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())
