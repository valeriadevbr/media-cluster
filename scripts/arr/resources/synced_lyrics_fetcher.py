import sys
import time
import requests
from lrclib import LrcLibAPI

def log_stderr(msg):
  timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
  print(f"[{timestamp}] {msg}", file=sys.stderr)

def fetch_from_lrclib_strict(artist, title, album, duration, max_retries=3):
  """Busca NO LRCLib usando match exato com metadados completos."""
  api = LrcLibAPI(user_agent="LidarrLyricsFetcher/1.0")

  try:
    duration_int = int(float(duration)) if duration else None
  except Exception:
    duration_int = None

  for attempt in range(max_retries):
    try:
      song = api.get_lyrics(
        track_name=title,
        artist_name=artist,
        album_name=album,
        duration=duration_int
      )

      if song and song.synced_lyrics:
        log_stderr(f"[LRCLib Strict] sucesso na tentativa {attempt+1}/{max_retries}")
        return song.synced_lyrics

      return None

    except Exception as e:
      log_stderr(f"[LRCLib Strict] erro na tentativa {attempt+1}/{max_retries}: {e}")
      time.sleep(0.5)
      if attempt >= max_retries - 1:
        return None

def fetch_from_lrclib_search(artist, title, max_retries=3):
  """Busca no LRCLib usando pesquisa (loosy) como fallback."""
  api = LrcLibAPI(user_agent="LidarrLyricsFetcher/1.0")

  for attempt in range(max_retries):
    try:
      results = api.search_lyrics(track_name=title, artist_name=artist)
      if results:
        for res in results:
          if res.synced_lyrics:
            full_lyrics = api.get_lyrics_by_id(res.id)
            if full_lyrics and full_lyrics.synced_lyrics:
              log_stderr(f"[LRCLib Search] sucesso na tentativa {attempt+1}/{max_retries}")
              return full_lyrics.synced_lyrics

      return None

    except Exception as e:
      log_stderr(f"[LRCLib Search] erro na tentativa {attempt+1}/{max_retries}: {e}")
      time.sleep(0.5)
      if attempt >= max_retries - 1:
        return None

def fetch_from_netease(artist, title, max_retries=3):
  """Fallback para o NetEase usando requests direto com retry."""
  for attempt in range(max_retries):
    try:
      search_url = "https://music.163.com/api/search/get"
      search_params = {"s": f"{title} {artist}", "type": 1, "limit": 1}
      r = requests.get(search_url, params=search_params, timeout=10)
      data = r.json()

      if data.get("result", {}).get("songs"):
        song_id = data["result"]["songs"][0]["id"]
        lyric_url = "https://music.163.com/api/song/lyric"
        lyric_params = {"id": song_id, "lv": 1, "kv": 1, "tv": -1}
        r = requests.get(lyric_url, params=lyric_params, timeout=10)
        lyric_data = r.json()

        lrc = lyric_data.get("lrc", {}).get("lyric")
        if lrc and "[" in lrc:
          log_stderr(f"[NetEase] sucesso na tentativa {attempt+1}/{max_retries}")
          return lrc

      return None

    except Exception as e:
      log_stderr(f"[NetEase] erro na tentativa {attempt+1}/{max_retries}: {e}")
      time.sleep(0.5)
      if attempt >= max_retries - 1:
        return None

def fetch_from_ovh(artist, title, max_retries=3):
  """Fallback para Lyrics.ovh (apenas texto plano)."""
  for attempt in range(max_retries):
    try:
      url = f"https://api.lyrics.ovh/v1/{artist}/{title}"
      r = requests.get(url, timeout=10)
      if r.status_code == 200:
        data = r.json()
        lyrics = data.get("lyrics")
        if lyrics:
          log_stderr(f"[Ovh] sucesso na tentativa {attempt+1}/{max_retries}")
          return lyrics
      return None
    except Exception as e:
      log_stderr(f"[Ovh] erro na tentativa {attempt+1}/{max_retries}: {e}")
      time.sleep(0.5)
      if attempt >= max_retries - 1:
        return None

def fetch_lyrics(artist, album, title, duration):
  providers = [
    lambda: fetch_from_lrclib_strict(artist, title, album, duration), # 1. LRCLib Strict (Match Exato com Album/Duration)
    lambda: fetch_from_lrclib_search(artist, title),                  # 2. LRCLib Search (Busca Genérica)
    lambda: fetch_from_ovh(artist, title),                            # 3. Lyrics.ovh (Texto Plano)
    lambda: fetch_from_netease(artist, title)                         # 4. NetEase (Sincronizado)
  ]

  for fetcher in providers:
    lyrics = fetcher()
    if lyrics:
      return lyrics

  return None

if __name__ == "__main__":
  if len(sys.argv) < 3:
    sys.exit(1)

  artist_name = sys.argv[1]
  album_title = sys.argv[2] if len(sys.argv) > 2 else None
  track_title = sys.argv[3] if len(sys.argv) > 3 else None
  duration_val = sys.argv[4] if len(sys.argv) > 4 else None

  if track_title:
    track_title = track_title.replace("|", " ").strip()

  result = fetch_lyrics(artist_name, album_title, track_title, duration_val)
  if result:
    print(result)
    sys.exit(0)
  else:
    sys.exit(1)
