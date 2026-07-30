import urllib.request
import json
import zipfile
import os

def download_ahk2exe():
    target_dir = os.path.join(os.path.dirname(__file__), "Ahk2Exe")
    os.makedirs(target_dir, exist_ok=True)
    zip_path = os.path.join(target_dir, "Ahk2Exe.zip")
    
    api_url = "https://api.github.com/repos/AutoHotkey/Ahk2Exe/releases/latest"
    req = urllib.request.Request(api_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    
    download_url = data["assets"][0]["browser_download_url"]
    print(f"Downloading Ahk2Exe from {download_url}...")
    
    dl_req = urllib.request.Request(download_url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(dl_req) as resp_file, open(zip_path, "wb") as out_file:
        out_file.write(resp_file.read())
    
    print("Extracting Ahk2Exe...")
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        zip_ref.extractall(target_dir)
    print(f"Ahk2Exe extracted successfully to: {target_dir}")

if __name__ == "__main__":
    download_ahk2exe()
