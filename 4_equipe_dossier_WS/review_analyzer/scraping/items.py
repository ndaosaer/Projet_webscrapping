import scrapy

class ReviewItem(scrapy.Item):
    product_name  = scrapy.Field()
    platform      = scrapy.Field()
    rating        = scrapy.Field()
    comment_text  = scrapy.Field()
    comment_date  = scrapy.Field()
    author        = scrapy.Field()
    url_source    = scrapy.Field()
    scraped_at    = scrapy.Field()