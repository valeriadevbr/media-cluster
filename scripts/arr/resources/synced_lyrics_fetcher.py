import sys
import syncedlyrics

def fetch_lyrics(artist, title):
    try:
        lyrics = syncedlyrics.search(
          f"{title} {artist}",
          providers=["LrcLib", "Musixmatch", "Megalobiz", "NetEase"]
        )
        if lyrics:
            return lyrics
        return None
    except Exception:
        return None

if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(1)

    artist_name = sys.argv[1]
    track_title = sys.argv[2]

    result = fetch_lyrics(artist_name, track_title)
    if result:
        print(result)
        sys.exit(0)
    else:
        sys.exit(1)
