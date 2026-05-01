"""
ui_improvements.py
------------------
Applies CSS styling improvements to the System Automation Hub website using
headless Chrome via Selenium WebDriver.

This script:
1. Launches a headless Chrome browser managed by webdriver-manager.
2. Navigates to the deployed GitHub Pages site.
3. Injects a <style> element that overrides the page's default typography and
   header appearance.
4. Prints a confirmation message and exits cleanly.

Dependencies:
    selenium          - Browser automation framework.
    webdriver-manager - Automatic ChromeDriver version management.

Usage:
    python scripts/ui_improvements.py

Notes:
    - Requires Google Chrome to be installed on the host machine.
    - The script runs in headless mode, so no browser window is displayed.
    - Injected styles are ephemeral (session-only); they do not persist to the
      source repository.  Use this script for visual smoke-testing only.
"""

from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.chrome.options import Options
from webdriver_manager.chrome import ChromeDriverManager
import time

# Configure Chrome to run without a GUI (headless mode)
chrome_options = Options()
chrome_options.add_argument("--headless=new")
chrome_options.add_argument("--disable-gpu")

driver = webdriver.Chrome(
    service=Service(ChromeDriverManager().install()),
    options=chrome_options
)

site = "https://ruh-al-tarikh.github.io/System-Automation-Hub/"
driver.get(site)

# Allow the page to fully render before injecting styles
time.sleep(3)

# Inject a <style> element into <head> to improve typography and header contrast
driver.execute_script("""
var style = document.createElement('style');
style.innerHTML = `
body {font-family: Segoe UI; line-height:1.6;}
header {background:#111827;color:white;padding:12px;}
`;
document.head.appendChild(style);
""")

print("UI automation executed")

driver.quit()
