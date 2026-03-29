import sys, time
sys.path.insert(0, '.')
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By

options = Options()
options.add_argument("--window-size=1920,1080")
options.add_argument("--disable-blink-features=AutomationControlled")
options.add_experimental_option("excludeSwitches", ["enable-automation"])
options.add_experimental_option("useAutomationExtension", False)
options.add_argument("--user-data-dir=C:\\Temp\\chrome_amazon")
options.add_argument(
    "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36"
)

driver = webdriver.Chrome(options=options)
driver.get("https://www.amazon.fr/product-reviews/B075FC8ZJ3/?sortBy=recent")

print("Attente 12 secondes...")
time.sleep(12)

# Scroll
driver.execute_script("window.scrollTo(0, 1000)")
time.sleep(3)

print(f"Titre : {driver.title[:80]}")

# Tous les sélecteurs possibles
tests = [
    "[data-hook='review']",
    "[data-hook='review-collapsed']",
    "div[data-hook]",
    "div.review-views",
    "div#cm_cr-review_list",
    "div.a-section.review",
]

for sel in tests:
    n = len(driver.find_elements(By.CSS_SELECTOR, sel))
    if n > 0:
        print(f"  ✅ {sel} → {n}")
    else:
        print(f"  ❌ {sel} → 0")

# HTML brut autour des avis
html = driver.page_source
idx = html.find("data-hook=\"review\"")
if idx > 0:
    print(f"\n✅ 'data-hook=review' trouvé dans le HTML à l'index {idx}")
    print(html[idx:idx+300])
else:
    print("\n❌ 'data-hook=review' ABSENT du HTML")
    idx2 = html.find("review")
    print(f"Premier 'review' trouvé à : {idx2}")
    print(html[idx2:idx2+200])

input("\nEntrée pour fermer...")
driver.quit()