import sys, os, time

# Fix CWD
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

options = Options()
options.add_argument('--window-size=1920,1080')
options.add_argument('--disable-blink-features=AutomationControlled')
options.add_experimental_option('excludeSwitches', ['enable-automation'])
options.add_experimental_option('useAutomationExtension', False)
options.add_argument('--user-data-dir=C:\\Temp\\chrome_selenium')
options.add_argument(
    "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
    "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/144.0.0.0 Safari/537.36"
)

driver = webdriver.Chrome(options=options)
driver.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")

URL = 'https://www.tripadvisor.fr/Restaurant_Review-g293831-d780235-Reviews-Restaurant_Lagon_1-Dakar_Dakar_Region.html'
print(f" Ouverture de : {URL}")
driver.get(URL)

# Accepter cookies si présent
try:
    btn = WebDriverWait(driver, 6).until(
        EC.element_to_be_clickable((By.XPATH, "//button[contains(text(),'Accepter')]"))
    )
    btn.click()
    print("✓ Cookies acceptés")
    time.sleep(2)
except Exception:
    pass

# Attente longue pour que la page charge complètement
print(" Attente chargement page (15s)...")
time.sleep(15)

# ── Diagnostic 1 : titre de la page ──────────────────────────────────────────
print(f"\n Titre de la page : {driver.title}")

# ── Diagnostic 2 : cherche le H1 ─────────────────────────────────────────────
h1_elements = driver.find_elements(By.TAG_NAME, "h1")
print(f"\n H1 trouvés : {len(h1_elements)}")
for h1 in h1_elements:
    print(f"   → '{h1.text.strip()}' | classes: '{h1.get_attribute('class')}'")

# ── Diagnostic 3 : cartes d'avis ─────────────────────────────────────────────
cards = driver.find_elements(By.CSS_SELECTOR, "div[data-automation='reviewCard']")
print(f"\n Cartes d'avis [data-automation='reviewCard'] : {len(cards)}")

# ── Diagnostic 4 : autres sélecteurs possibles ───────────────────────────────
alt_selectors = [
    "div[data-reviewid]",
    "div.review-container",
    "div._c",
    "[data-automation='reviewsList'] > div",
    "div.LbPSX",
]
print("\n Test de sélecteurs alternatifs :")
for sel in alt_selectors:
    elems = driver.find_elements(By.CSS_SELECTOR, sel)
    print(f"   {sel!r:55} → {len(elems)} éléments")

# ── Sauvegarde HTML complet ───────────────────────────────────────────────────
output_path = os.path.join(os.getcwd(), 'page_complete.html')
with open(output_path, 'w', encoding='utf-8') as f:
    f.write(driver.page_source)
print(f"\n HTML complet sauvegardé → {output_path}")

# ── Sauvegarde de la première carte si trouvée ───────────────────────────────
if cards:
    card_path = os.path.join(os.getcwd(), 'carte_complete.html')
    with open(card_path, 'w', encoding='utf-8') as f:
        f.write(cards[0].get_attribute('innerHTML'))
    print(f" Première carte sauvegardée → {card_path}")

    # Affiche un aperçu du texte de la carte
    print(f"\n Texte brut de la 1ère carte :\n{cards[0].text[:500]}")
else:
    print("\n  Aucune carte trouvée — TripAdvisor bloque probablement la requête.")
    print("    Ouvre 'page_complete.html' pour voir ce qui est retourné.")

driver.quit()
print("\n Diagnostic terminé.")
