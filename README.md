# Umay: Network Traffic Analysis & Spatial Visualization System

![Project Status](https://img.shields.io/badge/Status-In--Development-yellow)
![Platform](https://img.shields.io/badge/Platform-Linux%20%2F%20Mobile-lightgrey)
![License](https://img.shields.io/badge/License-MIT-blue)
![Python](https://img.shields.io/badge/Backend-Python%203.10%2B-green)
![Flutter](https://img.shields.io/badge/Frontend-Flutter-blue)

---

## English Description

Umay is a high-performance network monitoring and visualization framework. It is designed to intercept DNS queries at the network layer and map the geographical distribution of data traffic in real-time. By bridging the gap between low-level packet sniffing and high-level mobile visualization, Umay provides an analytical perspective on network privacy and data flow.

> **Important:** This project is currently in the active development phase and is not yet stable.

### Core Architecture
- **Sniffer Engine:** Utilizes Python and the Scapy library to intercept UDP/53 traffic.
- **Backend Infrastructure:** Built on FastAPI with WebSocket support for low-latency data broadcasting.
- **Client Interface:** A Flutter-based mobile application for real-time spatial mapping and traffic logging.

---

## Türkçe Açıklama

Umay, yüksek performanslı bir ağ izleme ve görselleştirme sistemidir. Ağ katmanındaki DNS sorgularını yakalamak ve veri trafiğinin coğrafi dağılımını gerçek zamanlı olarak haritalandırmak için tasarlanmıştır. Düşük seviyeli paket yakalama (sniffing) ile üst seviye mobil görselleştirmeyi birleştiren Umay, ağ gizliliği ve veri akışı üzerinde analitik bir perspektif sunar.

> **Önemli:** Bu proje henüz geliştirme aşamasındadır ve henüz stabil değildir.

### Temel Mimari
- **Yakalama Motoru:** UDP/53 trafiğini analiz etmek için Python ve Scapy kütüphanesini kullanır.
- **Sunucu Altyapısı:** Verileri düşük gecikmeyle aktarmak için FastAPI ve WebSocket mimarisi üzerine kurulmuştur.
- **İstemci Arayüzü:** Gerçek zamanlı mekansal haritalama ve trafik kaydı için Flutter tabanlı mobil uygulama.

---

## Project Structure / Proje Yapısı

```text
Umay/
├── server_linux/    # Sniffer, API, and Core Logic
├── client_mobile/   # Flutter Application
├── docs/            # Technical Documentation
└── scripts/         # System Configuration Tools
```
## 🚀 Quick Start / Hızlı Başlangıç

Detailed installation and configuration steps can be found in the documentation folder. / Detaylı kurulum ve yapılandırma adımlarına dokümantasyon klasörü üzerinden ulaşabilirsiniz.

| Resource / Kaynak | Description / Açıklama |
|:---|:---|
| [Setup Guide](./docs/SETUP_GUIDE.md) | Installation and Environment Setup / Kurulum ve Ortam Hazırlığı |
| [Architecture](./docs/ARCHITECTURE.md) | System Design and Logic / Sistem Tasarımı ve Mantığı |
| [API Docs](./docs/API_ENDPOINTS.md) | Endpoint and Protocol Details / Bağlantı Noktası Detayları |

---

## ⚖️ Disclaimer / Feragatname

**English:** This software is developed strictly for educational and network security awareness purposes. The developer is not responsible for any misuse. Users are solely responsible for complying with local and international laws regarding network monitoring and data privacy.

**Türkçe:** Bu yazılım tamamen eğitim ve ağ güvenliği farkındalığı amacıyla geliştirilmiştir. Kötüye kullanım durumunda geliştirici sorumluluk kabul etmez. Kullanıcılar, ağ izleme ve veri gizliliği konusundaki yerel ve uluslararası yasalara uymakla yükümlüdür.

---

## 📜 License / Lisans

Distributed under the **MIT License**. See the `LICENSE` file for more information. / **MIT Lisansı** altında dağıtılmaktadır. Daha fazla bilgi için `LICENSE` dosyasına göz atın.

---

**Maintained by:** [Yusuf Eroğlu](https://github.com/erogluyusuf)  
*Bridging the gap between network packets and spatial visualization.*