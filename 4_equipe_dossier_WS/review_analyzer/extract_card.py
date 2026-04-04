import sys, time
sys.path.insert(0, '.')
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By

options = Options()
options.add_argument('--window-size=1920,1080')
options.add_argument('--disable-blink-features=AutomationControlled')
options.add_experimental_option('excludeSwitches', ['enable-automation'])
options.add_experimental_option('useAutomationExtension', False)
options.add_argument('--user-data-dir=C:\\Temp\\chrome_selenium')

driver = webdriver.Chrome(options=options)
driver.get('https://www.tripadvisor.fr/Restaurant_Review-g293831-d780235-Reviews-Restaurant_Lagon_1-Dakar_Dakar_Region.html')
time.sleep(12)

cards = driver.find_elements(By.CSS_SELECTOR, "div[data-automation='reviewCard']")
print(f'Cartes trouvées : {len(cards)}')

if cards:
    # Sauvegarder le HTML complet de la première carte
    with open('carte_complete.html', 'w', encoding='utf-8') as f:
        f.write(cards[0].get_attribute('innerHTML'))
    
    print('✓ Fichier carte_complete.html sauvegardé !')
else:
    print('✗ Aucune carte trouvée')

driver.quit()
