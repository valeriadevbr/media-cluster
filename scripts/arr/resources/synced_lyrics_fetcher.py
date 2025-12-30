import sys
import time
import requests
from lrclib import LrclibClient

def fetch_from_netease(artist, title):
    """Fallback simples para o NetEase usando requests direto."""
    try:
        # 1. Busca o ID da música
        search_url = "https://music.163.com/api/search/get"
        search_params = {"s": f"{title} {artist}", "type": 1, "limit": 1}
        r = requests.get(search_url, params=search_params, timeout=10)
        data = r.json()

        if data.get("result", {}).get("songs"):
            song_id = data["result"]["songs"][0]["id"]

            # 2. Busca a letra pelo ID
            lyric_url = "https://music.163.com/api/song/lyric"
            lyric_params = {"id": song_id, "lv": 1, "kv": 1, "tv": -1}
            r = requests.get(lyric_url, params=lyric_params, timeout=10)
            lyric_data = r.json()

            lrc = lyric_data.get("lrc", {}).get("lyric")
            if lrc and "[" in lrc:
                return lrc
    except Exception as e:
        print(f"Erro NetEase Fallback: {e}", file=sys.stderr)
    return None

def fetch_lyrics(artist, title):
    client = LrclibClient()
    max_retries = 3

    for attempt in range(max_retries):
        try:
            # 1. Tenta LRCLib primeiro (mais estável e sincronizado)
            # O get() tenta buscar o melhor match usando metadados
            song = client.get(track_name=title, artist_name=artist)

            if song and song.synced_lyrics:
                return song.synced_lyrics

            # 2. Se falhar, tenta Busca Geral no LRCLib
            results = client.search(track_name=title, artist_name=artist)
            if results:
                for res in results:
                    if res.synced_lyrics:
                        return res.synced_lyrics

            # 3. Fallback para NetEase (Independente do lrclib-python)
            netease_lrc = fetch_from_netease(artist, title)
            if netease_lrc:
                return netease_lrc

            return None

        except Exception as e:
            if attempt < max_retries - 1:
                print(f"Erro (SSL/Conexão): {e}. Retentando em 2s... ({attempt+1}/{max_retries})", file=sys.stderr)
                time.sleep(2)
            else:
                print(f"Erro fatal após {max_retries} tentativas: {e}", file=sys.stderr)
                return None

if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(1)

    artist_name = sys.argv[1]
    track_title = sys.argv[2]

    # Limpeza básica do título (remover caracteres de pipe comuns no Lidarr)
    track_title = track_title.replace("|", " ").strip()

    result = fetch_lyrics(artist_name, track_title)
    if result:
        print(result)
        sys.exit(0)
    else:
        sys.exit(1)
