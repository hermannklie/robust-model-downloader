# Robust Downloader for Large AI Models (Mistral 3 Large)

This repository provides a lightweight, fault-tolerant semi automatic shell script for downloading
large AI model files — especially useful in regions with **weak or unstable internet
connections** (e.g., Afrika, rural areas, limited mobile networks).

The script supports:
- automatic resume of partial downloads  
- robust retry logic on connection drop  
- safe continuation without corrupting files  
- minimal dependencies (standard Linux tools only)  

It is designed for downloading **Mistral 3 Large** or similar frontier model files from
Hugging Face or other authenticated model hosts.

---

## 🔑 Important: Insert your own login/token

Inside the script, replace the placeholder: PLACE YOUR TOKEN HERE

with **your actual Hugging Face login or access token**.  
Otherwise authentication will fail and the model cannot be downloaded.

following German version of readme.md 

# Frontier Model Download Script (Easy & Robust)

Dieses Skript hilft dir, **riesige KI-Modelle** herunterzuladen, auch wenn deine
Internetverbindung langsam, instabil oder ständig unterbrochen wird
(z. B. auf Inseln, mobilen Hotspots, ländlichen Gebieten).

Das Skript kann:
- einen abgebrochenen Download automatisch fortsetzen  
- bei Netzwerkfehlern mehrmals neu versuchen  
- große Dateien zuverlässig zu Ende laden  
- mit Login/Token arbeiten (z. B. Hugging Face)

Es funktioniert für **jedes Frontier-Modell**, du musst nur **zwei Dinge ändern**:

---

# 🔧 1. Deinen Login/Token eintragen

Ersetze im Skript 

TOKEN="PLACE YOUR TOKEN HERE" 

durch **deinen echten Hugging-Face-Token**  
oder deinen Login (je nach Anbieter).
Ohne diesen Token kann das Modell **nicht** heruntergeladen werden.

---

# 📦 2. Die Modell-URL ändern (für jedes andere Frontier-Modell)

Im Skript ersetze 

BASE_URL="https://huggingface.co/mistralai/Mistral-Large-3-675B-Base-2512/resolve/main"

durch die url zu deinem model.

# 3. Start und Ende
ImSkript ersetze 

START=00001
END=00272

durch die angezeigte Nummerierung mit der richtigen Anzahl 0 davor fpr dein model.

# 4. Beachte den richtigen Dateinamen und Endnummerierung

Im Skript ersetze

FILE="consolidated-${i}-of-00272.safetensors"

durch den richtigen Namen und letzten safetensor. Meist so etwas wie 

FILE="model-${i}-of-000163.safetensors"






