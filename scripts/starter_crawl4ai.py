"""
starter_crawl4ai.py — minimal LLM-ready crawl with crawl4ai
Run:  .\.venv\Scripts\python.exe scripts\starter_crawl4ai.py https://example.com
"""
import asyncio, sys
from crawl4ai import AsyncWebCrawler, BrowserConfig, CrawlerRunConfig, CacheMode


async def main(url: str):
    browser = BrowserConfig(headless=True, verbose=False)
    run = CrawlerRunConfig(
        cache_mode=CacheMode.BYPASS,
        page_timeout=60_000,
        wait_for="css:body",          # refine per-site
        scan_full_page=True,
        scroll_delay=0.5,
    )
    async with AsyncWebCrawler(config=browser) as crawler:
        result = await crawler.arun(url, config=run)
        if result.success:
            print("=== MARKDOWN ===")
            print(result.markdown[:4000])
            print("\n=== LINKS ===", len(result.links.get("internal", [])), "internal")
        else:
            print("FAILED:", result.error_message)


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else "https://example.com"
    asyncio.run(main(target))
