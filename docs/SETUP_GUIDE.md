# Setup and Configuration Guide / Kurulum ve Yapılandırma Rehberi

## Prerequisites / Ön Gereksinimler
- Python 3.10 or higher
- Linux OS (Root privileges required for packet sniffing)
- libpcap-dev library

## Installation Steps / Kurulum Adımları
1. **System Dependencies:** `sudo apt install libpcap-dev python3-pip`
2. **Environment:** `python3 -m venv venv && source venv/bin/activate`
3. **Libraries:** `pip install -r server_linux/requirements.txt`
4. **Network Config:** Run `scripts/setup_network.sh` to enable promiscuous mode.
5. **Execution:** `sudo ./venv/bin/python server_linux/main.py`

## Türkçe Not
Ağ paketlerini yakalamak için uygulamanın root yetkisiyle çalıştırılması zorunludur. Sanal ortam (venv) kullanımı, sistem kütüphanelerinin korunması açısından tavsiye edilir.