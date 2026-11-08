#!/usr/bin/env python3
import sys, json, time, re, os
import urllib.request, urllib.parse, http.cookiejar

QS_RUN_WP = os.environ.get("QS_RUN_WALLPAPER", "/tmp/quickshell/wallpaper")
CONTROL_FILE = os.path.join(QS_RUN_WP, "ddg_search_control")
PAUSE_TIMEOUT = 600

def get_state():
    try:
        with open(CONTROL_FILE, "r") as f:
            return f.read().strip()
    except Exception:
        return "run"

def main():
    if len(sys.argv) < 2: 
        return
        
    query = sys.argv[1].strip() + " wallpaper"
    
    cj = http.cookiejar.CookieJar()
    opener = urllib.request.build_opener(urllib.request.HTTPCookieProcessor(cj))
    urllib.request.install_opener(opener)

    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
        "Referer": "https://duckduckgo.com/"
    }

    search_url = f"https://duckduckgo.com/?q={urllib.parse.quote(query)}&iar=images&iax=images&ia=images&kp=1"
    vqd = None

    for _ in range(3):
        try:
            req = urllib.request.Request(search_url, headers=headers)
            html = urllib.request.urlopen(req, timeout=10).read().decode("utf-8")
            match = re.search(r'vqd=([0-9a-zA-Z_-]+)', html) or re.search(r'vqd[\'"]?\s*:\s*[\'"]?([0-9a-zA-Z_-]+)', html)
            
            if match: 
                vqd = match.group(1)
                break
        except Exception: 
            time.sleep(1)

    if not vqd: 
        return

    headers["Referer"] = search_url
    headers["Accept"] = "application/json, text/javascript, */*; q=0.01"

    next_url = None
    seen_urls = set()
    
    for _ in range(5): 
        state = get_state()
        if state == "stop": 
            break
            
        paused_at = time.monotonic()
        while state == "pause": 
            if time.monotonic() - paused_at >= PAUSE_TIMEOUT:
                sys.exit(0)
            time.sleep(1)
            state = get_state()

        params = {
            "l": "us-en",
            "o": "json",
            "q": query,
            "vqd": vqd,
            "f": ",,,",
            "p": "1",
            "ex": "-1"
        }

        if next_url: 
            url = "https://duckduckgo.com" + next_url
            if "p=1" not in url: url += "&p=1"
            if "vqd=" not in url: url += f"&vqd={vqd}"
        else:
            url = "https://duckduckgo.com/i.js?" + urllib.parse.urlencode(params)

        try:
            req = urllib.request.Request(url, headers=headers)
            response = urllib.request.urlopen(req, timeout=10)
            data = json.loads(response.read().decode("utf-8"))
            results = data.get("results", [])
            
            for res in results:
                width = int(res.get("width", 0))
                height = int(res.get("height", 0))
                if width >= 1920 and height >= 1080:
                    t, i = res.get("thumbnail"), res.get("image")
                    if t and i and i not in seen_urls:
                        seen_urls.add(i)
                        try:
                            sys.stdout.write(f"{t}|{i}\n")
                            sys.stdout.flush()
                        except BrokenPipeError:
                            os._exit(0) 
            
            next_url = data.get("next")
            if not next_url: 
                break
                
        except BrokenPipeError:
            os._exit(0)
        except Exception: 
            break

if __name__ == "__main__": 
    try:
        main()
        sys.stdout.flush()
    except BrokenPipeError:
        os._exit(0)
    except KeyboardInterrupt:
        os._exit(1)
    except Exception: 
        os._exit(1)
