BOT_NAME = "review_analyzer"

SPIDER_MODULES = ["scraping.spiders"]
NEWSPIDER_MODULE = "scraping.spiders"

# Respecte le robots.txt (éthique)
ROBOTSTXT_OBEY = True

# Délai poli entre les requêtes
DOWNLOAD_DELAY = 3
RANDOMIZE_DOWNLOAD_DELAY = True
AUTOTHROTTLE_ENABLED = True
AUTOTHROTTLE_START_DELAY = 2
AUTOTHROTTLE_MAX_DELAY = 10

# Concurrence limitée (1 seule requête à la fois)
CONCURRENT_REQUESTS = 1
CONCURRENT_REQUESTS_PER_DOMAIN = 1

# User-Agent par défaut
USER_AGENT = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/120.0.0.0 Safari/537.36"
)

# Pipeline activée
ITEM_PIPELINES = {
    "scraping.pipelines.ReviewPipeline": 300,
}

# Logs
LOG_LEVEL = "INFO"