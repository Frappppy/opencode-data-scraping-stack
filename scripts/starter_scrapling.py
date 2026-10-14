"""
starter_scrapling.py — self-healing extraction with Scrapling
Survives site redesigns (unlike raw CSS selectors).
Run:  .\.venv\Scripts\python.exe scripts\starter_scrapling.py https://news.ycombinator.com
"""
import sys
from scrapling.fetchers import Fetcher, DynamicFetcher


def static_example(url: str):
    page = Fetcher.get(url)
    # adaptive selector: finds best match even if classes change
    titles = page.css("span.titleline > a")
    for t in titles[:10]:
        print("-", t.text, "|", t.attrib.get("href"))


def stealth_example(url: str):
    # undetectable browser for JS / anti-bot sites
    page = DynamicFetcher.fetch(url, headless=True, timeout=30000)
    print(page.css("title")[0].text if page.css("title") else "no title")


if __name__ == "__main__":
    url = sys.argv[1] if len(sys.argv) > 1 else "https://news.ycombinator.com"
    mode = sys.argv[2] if len(sys.argv) > 2 else "static"
    (stealth_example if mode == "stealth" else static_example)(url)
