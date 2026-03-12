import argparse
import json
import requests
from bs4 import BeautifulSoup
import sys
from datetime import datetime

# ==========================================
# 工具函数：将日志输出到 stderr，避免污染 stdout 的 JSON 数据
# ==========================================
def log(message):
    sys.stderr.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [INFO] {message}\n")

def error_log(message):
    sys.stderr.write(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] [ERROR] {message}\n")

# ==========================================
# 爬虫策略模块
# ==========================================
class Scraper:
    def __init__(self, limit=5):
        self.limit = limit
        self.headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
        }

    def fetch_hacker_news(self):
        log("Fetching Hacker News top stories...")
        # Hacker News 官方提供了无需鉴权的 Firebase API
        url = "https://hacker-news.firebaseio.com/v0/topstories.json"
        try:
            story_ids = requests.get(url, timeout=10).json()[:self.limit]
            results = []
            for sid in story_ids:
                item_url = f"https://hacker-news.firebaseio.com/v0/item/{sid}.json"
                item = requests.get(item_url, timeout=10).json()
                results.append({
                    "title": item.get("title", ""),
                    "url": item.get("url", f"https://news.ycombinator.com/item?id={sid}"),
                    "source": "Hacker News"
                })
            return results
        except Exception as e:
            error_log(f"Hacker News Error: {e}")
            return []

    def fetch_github_trending(self):
        log("Fetching GitHub Trending...")
        url = "https://github.com/trending"
        try:
            response = requests.get(url, headers=self.headers, timeout=10)
            soup = BeautifulSoup(response.text, 'html.parser')
            repos = soup.select('article.Box-row')[:self.limit]
            results = []
            for repo in repos:
                title_elem = repo.select_one('h2 a')
                desc_elem = repo.select_one('p')
                title = title_elem.text.strip().replace('\n', '').replace(' ', '') if title_elem else "Unknown"
                url = "https://github.com" + title_elem['href'] if title_elem else ""
                desc = desc_elem.text.strip() if desc_elem else "No description"
                results.append({
                    "title": title,
                    "description": desc,
                    "url": url,
                    "source": "GitHub Trending"
                })
            return results
        except Exception as e:
            error_log(f"GitHub Error: {e}")
            return []

    def fetch_product_hunt(self):
        log("Fetching Product Hunt via RSS proxy (since official API requires OAuth)...")
        # 使用第三方 RSS 转 JSON 或直接抓取。此处演示基于页面结构的模拟
        # 实际生产中建议使用 Product Hunt Developer API
        url = "https://www.producthunt.com/"
        try:
            # 简化版抓取逻辑示例
            response = requests.get(url, headers=self.headers, timeout=10)
            soup = BeautifulSoup(response.text, 'html.parser')
            # 这里的 selector 需根据网站迭代定期更新
            items = soup.select('a[data-test^="post-item"]')[:self.limit]
            results = []
            for item in items:
                results.append({
                    "title": item.text.strip(),
                    "url": "https://www.producthunt.com" + item.get('href', ''),
                    "source": "Product Hunt"
                })
            return results
        except Exception as e:
            error_log(f"Product Hunt Error: {e}")
            return []

    def fetch_guokr(self):
        log("Fetching Guokr (果壳网) scientific articles...")
        # 抓取果壳科学频道
        url = "https://www.guokr.com/scientific/"
        try:
            response = requests.get(url, headers=self.headers, timeout=10)
            soup = BeautifulSoup(response.text, 'html.parser')
            articles = soup.select('div.layout-main div.content-item')[:self.limit]
            results = []
            for article in articles:
                a_tag = article.select_one('a.title')
                if a_tag:
                    results.append({
                        "title": a_tag.text.strip(),
                        "url": a_tag.get('href', ''),
                        "source": "Guokr"
                    })
            return results
        except Exception as e:
            error_log(f"Guokr Error: {e}")
            return []

# ==========================================
# 入口与分发
# ==========================================
def main():
    parser = argparse.ArgumentParser(description="OpenClaw Data Producer")
    parser.add_argument("--site", type=str, required=True, choices=['hackernews', 'github', 'producthunt', 'guokr', 'all'], help="Target website to scrape")
    parser.add_argument("--limit", type=int, default=5, help="Number of items to fetch per site")
    
    args = parser.parse_args()
    scraper = Scraper(limit=args.limit)
    
    data = []
    
    if args.site in ['hackernews', 'all']:
        data.extend(scraper.fetch_hacker_news())
    if args.site in ['github', 'all']:
        data.extend(scraper.fetch_github_trending())
    if args.site in ['producthunt', 'all']:
        data.extend(scraper.fetch_product_hunt())
    if args.site in ['guokr', 'all']:
        data.extend(scraper.fetch_guokr())

    # 将最终数据封装为 OpenClaw 友好的标准格式
    output_payload = {
        "producer": "cron_spider_v1",
        "generated_at": datetime.now().isoformat(),
        "total_items": len(data),
        "data": data
    }

    # 严格使用 print 输出 JSON 到 stdout
    print(json.dumps(output_payload, ensure_ascii=False, indent=2))

if __name__ == "__main__":
    main()
