import sys
import json
import re
from html.parser import HTMLParser

class GeniusLyricsParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_lyrics_container = False
        self.captured_text = []
        self.div_level = 0
        self.found_container = False

    def handle_starttag(self, tag, attrs):
        if tag == 'div':
            is_target = False
            for k, v in attrs:
                if k == 'data-lyrics-container' and v == 'true':
                    is_target = True
                    break

            if is_target:
                self.in_lyrics_container = True
                self.found_container = True
                self.div_level += 1
            elif self.in_lyrics_container:
                self.div_level += 1

        if self.in_lyrics_container and tag == 'br':
            self.captured_text.append('\n')

    def handle_endtag(self, tag):
        if self.in_lyrics_container and tag == 'div':
            self.div_level -= 1
            if self.div_level == 0:
                self.in_lyrics_container = False

    def handle_data(self, data):
        if self.in_lyrics_container:
            self.captured_text.append(data)

def parse_genius_html(html_content):
    parser = GeniusLyricsParser()
    parser.feed(html_content)

    if not parser.found_container:
        return None

    full_text = "".join(parser.captured_text)
    lines = [line.strip() for line in full_text.splitlines()]
    clean_text = "\n".join(filter(None, lines))

    return clean_text

if __name__ == "__main__":
    html_content = sys.stdin.read()
    if not html_content:
        sys.exit(1)

    lyrics = parse_genius_html(html_content)

    if lyrics:
        print(lyrics)
    else:
        sys.exit(1)
