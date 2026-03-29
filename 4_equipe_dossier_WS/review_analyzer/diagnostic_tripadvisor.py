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
options.add_argument(
    "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) "
    "Chrome/144.0.0.0 Safari/537.36"
)

# Dossier temporaire pour éviter le conflit de profil
options.add_argument("--user-data-dir=C:\\Temp\\chrome_selenium")

driver = webdriver.Chrome(options=options)
driver.execute_script(
    "Object.defineProperty(navigator, 'webdriver', {get: () => undefined})"
)

print("Ouverture TripAdvisor...")
driver.get(
    "https://www.tripadvisor.fr/Restaurant_Review-g293831-d780235-"
    "Reviews-Restaurant_Lagon_1-Dakar_Dakar_Region.html"
)

print("Attente 15 secondes...")
time.sleep(15)

print(f"Titre : {driver.title}")

cards = driver.find_elements(
    By.CSS_SELECTOR, "div[data-automation='reviewCard']"
)
print(f"Cartes trouvées : {len(cards)}")

if cards:
    print("\n=== HTML première carte ===")
    print(cards[0].get_attribute("innerHTML")[:2000])
else:
    print("\n=== Début HTML page ===")
    print(driver.page_source[:800])

input("\nEntrée pour fermer...")
driver.quit()