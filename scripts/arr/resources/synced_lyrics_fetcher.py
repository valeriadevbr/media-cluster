import sys
import syncedlyrics

def fetch_lyrics(artist, title):
    try:
        # Search for lyrics using the requested format: "TRACK_TITLE ARTIST_NAME"
        lyrics = syncedlyrics.search(f"{title} {artist}",
                                     providers=["Musixmatch", "LrcLib", "NetEase", "Megalobiz"])
        if lyrics:
            return lyrics
        return None
    except Exception as e:
        # Silently fail so the shell script can handle the missing lyrics
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
