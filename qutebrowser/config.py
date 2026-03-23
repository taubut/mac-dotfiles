# Catppuccin Macchiato theme for qutebrowser
import sys
sys.path.append(str(config.configdir / 'catppuccin'))
import catppuccin

# Load existing settings
config.load_autoconfig()

# Apply Catppuccin Macchiato theme (True = plain menu rows)
catppuccin.setup(c, 'macchiato', True)

# Default homepage
c.url.start_pages = ['https://aur.archlinux.org/']
c.url.default_page = 'https://aur.archlinux.org/'

# Open new tabs in background
c.tabs.background = True

# Bigger tabs
c.fonts.tabs.selected = '13pt JetBrainsMono Nerd Font'
c.fonts.tabs.unselected = '13pt JetBrainsMono Nerd Font'
c.tabs.padding = {'bottom': 6, 'left': 8, 'right': 8, 'top': 6}

# Bigger completion/status bar
c.fonts.completion.entry = '13pt JetBrainsMono Nerd Font'
c.fonts.completion.category = 'bold 13pt JetBrainsMono Nerd Font'
c.fonts.statusbar = '13pt JetBrainsMono Nerd Font'

# Block autoplay
c.content.autoplay = False

# SearXNG as default search engine
c.url.searchengines = {
    'DEFAULT': 'http://192.168.1.185:9090/search?q={}',
    'g': 'https://www.google.com/search?q={}',
    'ddg': 'https://duckduckgo.com/?q={}',
    'aur': 'https://aur.archlinux.org/packages?K={}',
    'yt': 'https://www.youtube.com/results?search_query={}',
    'gh': 'https://github.com/search?q={}',
}

# Spoof as Windows Chrome
c.content.headers.user_agent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

# Spoof client hints headers
c.content.headers.custom = {
    'Sec-CH-UA-Platform': '"Windows"',
    'Sec-CH-UA-Platform-Version': '"10.0.0"',
    'Sec-CH-UA': '"Chromium";v="131", "Google Chrome";v="131", "Not?A_Brand";v="99"',
}

# Ad blocking (uses both hosts file and Brave's adblocker)
c.content.blocking.method = 'both'
c.content.blocking.adblock.lists = [
    "https://easylist.to/easylist/easylist.txt",
    "https://easylist.to/easylist/easyprivacy.txt",
    "https://raw.githubusercontent.com/uBlockOrigin/uAssets/master/filters/filters.txt",
]
