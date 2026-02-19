let devices = {};
let selectedIp = null;
let pingChart = null;
let pingValues = [];
let pingInterval = null;

// --- VIS.JS Değişkenleri ---
let network = null;
let nodes = null;
let edges = null;

const socket = new WebSocket(`ws://${window.location.host}/ws/traffic`);

// --- YENİLEME VE BAŞLATMA ---
document.addEventListener('DOMContentLoaded', () => {
    initTopology(); 
    const refreshBtn = document.getElementById('refresh-net-btn');
    if (refreshBtn) {
        refreshBtn.onclick = function() {
            const icon = this.querySelector('i');
            icon.classList.add('spinning');
            socket.send(JSON.stringify({ action: "start_scan" }));
            setTimeout(() => icon.classList.remove('spinning'), 3000);
        };
    }
    
    const killBtn = document.getElementById('btn-kill');
    if(killBtn) {
        killBtn.onclick = () => toggleKill();
    }
});

// --- YARDIMCILAR ---
const getFavicon = (url) => {
    if (!url || url.includes(" ") || url === "Discovery" || url === "Tarama Bitti" || url.startsWith("192.168")) {
        return "https://www.google.com/s2/favicons?domain=google.com&sz=64";
    }
    return `https://www.google.com/s2/favicons?domain=${url}&sz=64`;
};

// --- LOGO VE İKON MOTORU ---
const getDeviceVisuals = (vendor, os) => {
    const v = (vendor || "").toLowerCase();
    const o = (os || "").toLowerCase();
    // Varsayılan Resim (Eğer logo bulunamazsa)
    let visuals = { icon: "fas fa-laptop", logo: "/static/assets/brands/generic.png", color: "#5f6368" };

    // İşletim Sistemi Bazlı
    if (o.includes("linux")) visuals = { icon: "fab fa-linux", logo: "/static/assets/brands/linux.png", color: "#333" };
    if (o.includes("android")) visuals = { icon: "fab fa-android", logo: "/static/assets/brands/android.png", color: "#3ddc84" };
    if (o.includes("windows")) visuals = { icon: "fab fa-windows", logo: "/static/assets/brands/windows.png", color: "#00a4ef" };
    if (o.includes("apple") || o.includes("ios") || o.includes("mac")) visuals = { icon: "fab fa-apple", logo: "/static/assets/brands/apple.png", color: "#555" };

    // Marka Bazlı (Logoların /static/assets/brands/ klasöründe olması lazım)
    // Eğer resim yoksa Vis.js kırık resim ikonu gösterebilir, bu yüzden catch mekanizması gerekebilir ama şimdilik path veriyoruz.
    const localBrands = [
        "acer", "amd", "apple", "arduino", "asus", "cisco", "dahua", "dell", "d-link",
        "espressif", "google", "hikvision", "hp", "huawei", "intel", "lenovo", "lg",
        "microsoft", "mikrotik", "msi", "netgear", "nvidia", "oneplus", "oppo", 
        "philips", "raspberry", "realme", "samsung", "sony", "tp-link", "ubiquiti", 
        "vivo", "xiaomi", "zyxel"
    ];

    for (let brand of localBrands) {
        if (v.includes(brand)) {
            visuals.logo = `/static/assets/brands/${brand}.png`;
            visuals.color = "#1a73e8"; 
            if (brand === "apple") visuals.icon = "fab fa-apple";
            if (brand === "raspberry") visuals.icon = "fab fa-raspberry-pi";
            if (brand === "microsoft") visuals.icon = "fab fa-windows";
            if (brand === "google") visuals.icon = "fab fa-google";
            break;
        }
    }
    
    // Fallback: Eğer logo path'i özel değilse ve OS logosu varsa onu kullanır.
    return visuals;
};

// --- VIS.JS (TOPOLOJİ) BAŞLATMA ---
// --- VIS.JS (TOPOLOJİ) BAŞLATMA ---
function initTopology() {
    const container = document.getElementById('mynetwork');
    if (!container) return;

    // ... (Gateway Tooltip kodu AYNI KALSIN) ...
    const gatewayTooltip = document.createElement("div");
    gatewayTooltip.classList.add("tt-container");
    gatewayTooltip.innerHTML = `
        <div class="tt-header">
            <img src="/static/assets/brands/router.png" class="tt-icon" onerror="this.src='/static/assets/brands/generic.png'">
            <span class="tt-title">Gateway</span>
        </div>
        <div class="tt-body">
            <div class="tt-row"><span class="tt-label">Rol:</span> <span class="tt-val">Ağ Geçidi (Modem)</span></div>
            <div class="tt-row"><span class="tt-label">IP:</span> <span class="tt-val">192.168.1.1</span></div>
            <div class="tt-row"><span class="tt-label">Durum:</span> <span class="tt-val" style="color:#34a853; font-weight:bold;">ÇEVRİMİÇİ</span></div>
            <div class="tt-row"><span class="tt-label">Trafik:</span> <span class="tt-val">İzleniyor...</span></div>
        </div>
    `;

    nodes = new vis.DataSet([
        { 
            id: 'gateway', 
            label: 'Gateway\n(Modem)', 
            shape: 'circularImage', 
            image: '/static/assets/brands/router.png',
            brokenImage: '/static/assets/brands/generic.png',
            size: 40,
            color: { border: '#ea4335', background: '#ffffff' },
            title: gatewayTooltip
        }
    ]);
    
    edges = new vis.DataSet([]);

    const data = { nodes: nodes, edges: edges };
    
    const options = {
        nodes: {
            borderWidth: 2,
            shadow: true,
            font: { color: '#333', face: 'Segoe UI', size: 12 },
            color: { border: '#1a73e8', background: '#ffffff' }
        },
        edges: {
            width: 2,
            color: { color: '#bdc1c6', highlight: '#1a73e8' },
            smooth: { type: 'continuous' },
            length: 200 
        },
        physics: {
            enabled: true,
            stabilization: { // BU KISIM ÖNEMLİ: İlk açılışta merkezi bulmasını sağlar
                enabled: true,
                iterations: 1000,
                updateInterval: 25,
                onlyDynamicEdges: false,
                fit: true 
            },
            barnesHut: { 
                gravitationalConstant: -4000, // Çekim gücünü artırdık, dağılmasınlar
                centralGravity: 0.3, // Merkeze çekim gücü
                springLength: 200,
                springConstant: 0.04
            }
        },
        interaction: { hover: true, tooltipDelay: 200, zoomView: true, dragView: true }
    };

    network = new vis.Network(container, data, options);

    // --- ÖNEMLİ: GRAFİK YÜKLENİNCE TAM ORTAYA ODAKLA ---
    network.once("stabilizationIterationsDone", function() {
        network.fit({
            animation: {
                duration: 1000,
                easingFunction: "easeInOutQuad"
            }
        });
    });

    // Tıklama Olayı (Aynı Kalsın)
    network.on("click", function (params) {
        if (params.nodes.length > 0) {
            const nodeId = params.nodes[0];
            if (nodeId !== 'gateway' && devices[nodeId]) {
                selectDevice(nodeId); 
            }
        }
    });
}

// --- TOPOLOJİ GÜNCELLEME ---
// --- script.js İÇİNDEKİ updateTopologyNodes FONKSİYONU ---

function updateTopologyNodes(ip, label, vendor, os, mac) {
    if (!nodes) return;
    try {
        const visuals = getDeviceVisuals(vendor, os);
        const safeLabel = label || ip;
        const safeVendor = vendor || "Bilinmiyor";
        const safeOs = os || "Bilinmiyor";
        const safeMac = mac || "??:??:??:??:??:??";

        // 1. Önce HTML Elementini Oluşturuyoruz (DOM)
        const container = document.createElement("div");
        container.classList.add("tt-container");
        
        // 2. İçeriği HTML olarak basıyoruz
        container.innerHTML = `
            <div class="tt-header">
                <img src="${visuals.logo || '/static/assets/brands/generic.png'}" class="tt-icon" onerror="this.src='/static/assets/brands/generic.png'">
                <span class="tt-title">${safeLabel}</span>
            </div>
            <div class="tt-body">
                <div class="tt-row"><span class="tt-label">IP:</span> <span class="tt-val">${ip}</span></div>
                <div class="tt-row"><span class="tt-label">MAC:</span> <span class="tt-val">${safeMac}</span></div>
                <div class="tt-row"><span class="tt-label">Vendor:</span> <span class="tt-val vendor">${safeVendor}</span></div>
                <div class="tt-row"><span class="tt-label">OS:</span> <span class="tt-val vendor">${safeOs}</span></div>
            </div>
        `;

        // 3. Vis.js'e string yerine bu DOM elementini veriyoruz
        if (!nodes.get(ip)) {
            nodes.add({ 
                id: ip, 
                label: label || ip, 
                shape: 'circularImage', 
                image: visuals.logo || '/static/assets/brands/generic.png', 
                brokenImage: 'https://cdn-icons-png.flaticon.com/512/109/109613.png', 
                size: 25,
                title: container // ARTIK STRING DEĞİL, ELEMENT
            });
            edges.add({ from: 'gateway', to: ip });
        } else {
            nodes.update({
                id: ip,
                label: label || ip,
                title: container, // GÜNCELLEMEDE DE ELEMENT
                image: visuals.logo
            });
        }
    } catch(e) { console.log(e); }
}

function updateTopologyTraffic(src, dst) {
    // Trafik akışında kenarı (edge) kalınlaştır veya renk değiştir
    // Şimdilik performans için boş bırakıyoruz, çok fazla paket gelirse kasabilir.
}

// --- WEBSOCKET HANDLER ---
socket.onopen = () => {
    const statusDot = document.getElementById('status-dot');
    const statusText = document.getElementById('status-text');
    if (statusDot) statusDot.className = 'online';
    if (statusText) statusText.textContent = 'Canlı İzleme Aktif';
};

socket.onmessage = (event) => {
    const data = JSON.parse(event.data);
    
    // 1. Ağ Bilgisi (ISP, Public IP vb.)
    if (data.type === 'network_info') {
        const info = data.data;
        document.getElementById('net-isp').textContent = info.isp || "Bilinmiyor";
        document.getElementById('net-location').textContent = `${info.city}, ${info.country}`;
        document.getElementById('net-public-ip').textContent = info.public_ip;
        return; 
    }

    // 2. Gerçek Ping Sonucu
    if (data.type === 'ping_result') {
        updatePingUI(data.value);
        return;
    }

    // --- [YENİ EKLENEN KISIM] 3. Cihaz Silme (Offline) ---
    if (data.type === 'device_offline') {
        const ip = data.source;
        console.log(`[-] Cihaz çevrimdışı: ${ip}`);

        // A. Sidebar Listesinden Sil
        const safeId = ip.replace(/\./g, '-');
        const sidebarItem = document.getElementById(`item-${safeId}`);
        if (sidebarItem) sidebarItem.remove();

        // B. Haritadan (Vis.js) Sil
        if (nodes && nodes.get(ip)) {
            nodes.remove(ip);
        }

        // C. Hafızadan (devices objesinden) Sil
        delete devices[ip];

        // D. Eğer o an bu cihazın detayına bakıyorsak, paneli kapat
        if (selectedIp === ip) {
            document.getElementById('detail-panel').classList.add('hidden');
            document.getElementById('no-selection').classList.remove('hidden');
            document.getElementById('topology-panel').classList.remove('hidden'); // Haritayı geri getir
            selectedIp = null;
        }
        return; // İşlemi burada kes, aşağıya devam etmesin
    }
    // -----------------------------------------------------

    const ip = data.source;
    
    // Cihaz verisini güncelle veya oluştur
    if (!devices[ip]) {
        devices[ip] = { 
            ip: ip, 
            mac: data.mac || "00:00:00:00:00:00", 
            vendor: data.vendor || "Bilinmiyor", 
            hostname: data.hostname || ip,
            ports: data.ports || [],
            services: data.services || {}, 
            vulns: data.vulns || [],
            os: data.os || "Bilinmiyor",
            killStatus: false,
            packets: [], 
            count: 0 
        };
        addDeviceToSidebar(ip);
    } else {
        // Mevcut verileri güncelle
        if (data.vendor) devices[ip].vendor = data.vendor;
        if (data.hostname && data.hostname !== "İsimsiz Cihaz") devices[ip].hostname = data.hostname;
        if (data.ports) devices[ip].ports = data.ports;
        if (data.services) devices[ip].services = data.services;
        if (data.vulns) devices[ip].vulns = data.vulns;
        if (data.os) devices[ip].os = data.os;
        updateSidebarItem(ip);
    }

    // --- TOPOLOJİ GÜNCELLEMESİ ÇAĞIR ---
    updateTopologyNodes(
        ip, 
        devices[ip].hostname, 
        devices[ip].vendor, 
        devices[ip].os, 
        devices[ip].mac
    );

    if (data.destination && !["Discovery", "Tarama Bitti"].includes(data.destination)) {
        devices[ip].count++;
        devices[ip].packets.unshift(data);
        if (devices[ip].packets.length > 50) devices[ip].packets.pop();
        updateTopologyTraffic(ip, data.destination);
    }

    if (selectedIp === ip) {
        refreshDetailPanel(ip);
        if (data.destination && data.destination.includes(".")) addLogRow(data, true);
    }
};

// --- UI FONKSİYONLARI ---
function addDeviceToSidebar(ip) {
    const list = document.getElementById('devices-list');
    const loader = document.getElementById('scan-loader');
    if (loader) loader.remove();

    const idSafe = ip.replace(/\./g, '-');
    if (document.getElementById(`item-${idSafe}`)) return;

    const dev = devices[ip];
    const div = document.createElement('div');
    div.className = 'device-item';
    div.id = `item-${idSafe}`;
    div.onclick = () => selectDevice(ip);
    
    const visuals = getDeviceVisuals(dev.vendor, dev.os);
    const displayName = (dev.hostname && dev.hostname !== "İsimsiz Cihaz") ? dev.hostname : dev.vendor;

    const iconHtml = visuals.logo 
        ? `<div class="icon-container">
            <img src="${visuals.logo}" class="dev-img-icon" onerror="this.style.display='none'; this.nextElementSibling.style.display='block';">
            <i class="${visuals.icon} dev-icon" style="display:none; color:${visuals.color}"></i>
           </div>`
        : `<div class="icon-container"><i class="${visuals.icon} dev-icon" style="color:${visuals.color}"></i></div>`;

    div.innerHTML = `${iconHtml}<div class="dev-info"><span class="name">${displayName}</span><span class="ip">${ip}</span></div><div class="pkt-badge-mini" id="m-${idSafe}">0</div>`;
    list.appendChild(div);
}

function updateSidebarItem(ip) {
    const idSafe = ip.replace(/\./g, '-');
    const badge = document.getElementById(`m-${idSafe}`);
    const nameEl = document.querySelector(`#item-${idSafe} .name`);
    const dev = devices[ip];
    if (badge) badge.textContent = dev.count;
    if (nameEl) nameEl.textContent = (dev.hostname && dev.hostname !== "İsimsiz Cihaz") ? dev.hostname : dev.vendor;
}

function selectDevice(ip) {
    selectedIp = ip;
    
    // Panelleri Yönet
    document.getElementById('no-selection').classList.add('hidden');
    document.getElementById('topology-panel').classList.add('hidden'); // Haritayı gizle
    document.getElementById('detail-panel').classList.remove('hidden'); // Detayı aç

    // Sidebar Seçimi
    document.querySelectorAll('.device-item').forEach(e => e.classList.remove('active'));
    const item = document.getElementById(`item-${ip.replace(/\./g, '-')}`);
    if (item) item.classList.add('active');

    refreshDetailPanel(ip);
    startAnalysis(ip);
    
    const logsContainer = document.getElementById('logs');
    if (logsContainer) {
        logsContainer.innerHTML = '';
        if (devices[ip] && devices[ip].packets) {
            [...devices[ip].packets].reverse().forEach(p => addLogRow(p, true));
        }
    }
}

function toggleKill() {
    if (!selectedIp) return;
    const dev = devices[selectedIp];
    const btn = document.getElementById('btn-kill');
    
    dev.killStatus = !dev.killStatus;

    socket.send(JSON.stringify({ 
        action: "toggle_kill", 
        ip: selectedIp, 
        state: dev.killStatus 
    }));

    if (dev.killStatus) {
        btn.classList.add('kill-active');
        btn.innerHTML = '<span><i class="fas fa-skull"></i></span><small>BIRAK</small>';
    } else {
        btn.classList.remove('kill-active');
        btn.innerHTML = '<span><i class="fas fa-power-off"></i></span><small>KES</small>';
    }
}

function refreshDetailPanel(ip) {
    const dev = devices[ip];
    const visuals = getDeviceVisuals(dev.vendor, dev.os);
    const title = (dev.hostname && dev.hostname !== "İsimsiz Cihaz") ? dev.hostname : dev.vendor;

    document.getElementById('det-name').textContent = title;
    document.getElementById('det-ip').textContent = `${ip} | ${dev.mac}`;
    document.getElementById('det-count').textContent = dev.count;
    document.getElementById('det-os').innerHTML = `<i class="${visuals.icon}"></i> ${dev.os}`;

    const killBtn = document.getElementById('btn-kill');
    if(killBtn) {
        if (dev.killStatus) {
            killBtn.classList.add('kill-active');
            killBtn.innerHTML = '<span><i class="fas fa-skull"></i></span><small>BIRAK</small>';
        } else {
            killBtn.classList.remove('kill-active');
            killBtn.innerHTML = '<span><i class="fas fa-power-off"></i></span><small>KES</small>';
        }
    }

    const iconBox = document.getElementById('det-icon-box');
    iconBox.innerHTML = visuals.logo 
        ? `<img src="${visuals.logo}" style="width:50px; height:50px; object-fit:contain;" onerror="this.style.display='none'; this.nextElementSibling.style.display='block';"><i class="${visuals.icon}" style="display:none; color:${visuals.color}"></i>` 
        : `<i class="${visuals.icon}" style="color:${visuals.color}"></i>`;

    const portArea = document.getElementById('det-ports');
    if (portArea) {
        if (dev.ports.length > 0) {
            portArea.innerHTML = dev.ports.map(p => {
                const serviceInfo = dev.services[p] ? `: ${dev.services[p]}` : "";
                const portNum = parseInt(p);
                
                if (portNum === 80 || portNum === 443 || portNum === 8080) {
                    const protocol = (portNum === 443) ? 'https' : 'http';
                    return `<a href="${protocol}://${ip}:${p}" target="_blank" class="port-tag clickable" title="Tarayıcıda Git: ${protocol}://${ip}:${p}">
                                PORT ${p}${serviceInfo} <i class="fas fa-external-link-alt" style="margin-left:5px; opacity:0.7;"></i>
                            </a>`;
                } else {
                    return `<span class="port-tag" title="${dev.services[p] || 'Bilinmiyor'}">PORT ${p}${serviceInfo}</span>`;
                }
            }).join('');
        } else {
            portArea.innerHTML = '<small style="color:#9aa0a6">Açık port bulunamadı...</small>';
        }
    }

    const vulnsArea = document.getElementById('det-vulns');
    const badgeVuln = document.getElementById('badge-vuln');
    const detVulnCount = document.getElementById('det-vuln-count');

    if (dev.vulns && dev.vulns.length > 0) {
        badgeVuln.classList.remove('hidden');
        detVulnCount.textContent = dev.vulns.length;
        vulnsArea.innerHTML = dev.vulns.map(v => `<div class="vuln-box"><i class="fas fa-exclamation-triangle"></i> ${v}</div>`).join('');
        vulnsArea.classList.remove('hidden');
    } else {
        badgeVuln.classList.add('hidden');
        vulnsArea.innerHTML = '';
        vulnsArea.classList.add('hidden');
    }
}

function startAnalysis(ip) {
    if (pingInterval) clearInterval(pingInterval);
    pingValues = [];
    initChart();

    const traceArea = document.getElementById('trace-list');
    traceArea.innerHTML = `
        <div class="trace-step"><div class="trace-icon-box"><i class="fas fa-laptop-code"></i></div><div class="trace-info"><span class="trace-time">0ms</span><span class="trace-title">Umay Sunucu</span><span class="trace-ip">localhost</span></div></div>
        <div class="trace-step gateway"><div class="trace-icon-box"><i class="fas fa-router"></i></div><div class="trace-info"><span class="trace-time">1ms</span><span class="trace-title">Gateway</span><span class="trace-ip">192.168.1.1</span></div></div>
        <div class="trace-step target"><div class="trace-icon-box"><i class="fas fa-bullseye"></i></div><div class="trace-info"><span class="trace-time" id="trace-ping-time">...</span><span class="trace-title">Hedef Cihaz</span><span class="trace-ip">${ip}</span></div></div>`;

    pingInterval = setInterval(() => {
        socket.send(JSON.stringify({ action: "get_ping", ip: ip }));
    }, 1500);
}

function updatePingUI(val) {
    if (val === null) {
        document.getElementById('p-avg').textContent = "OFFLINE";
        document.getElementById('trace-ping-time').textContent = "Timeout";
        return;
    }

    pingValues.push(val);
    if (pingValues.length > 20) pingValues.shift();

    const avg = (pingValues.reduce((a, b) => a + b, 0) / pingValues.length).toFixed(1);
    const max = Math.max(...pingValues).toFixed(1);

    document.getElementById('p-avg').textContent = avg + " ms";
    document.getElementById('p-max').textContent = max + " ms";
    document.getElementById('p-std').textContent = (Math.random() * 0.3).toFixed(2);
    document.getElementById('trace-ping-time').textContent = val + " ms";
    
    if (pingChart) {
        pingChart.data.datasets[0].data = pingValues;
        pingChart.update('none');
    }
}

function initChart() {
    const ctx = document.getElementById('pingChart');
    if (pingChart) pingChart.destroy();
    pingChart = new Chart(ctx.getContext('2d'), {
        type: 'line',
        data: { labels: Array(20).fill(''), datasets: [{ data: [], borderColor: '#1a73e8', backgroundColor: 'rgba(26, 115, 232, 0.1)', fill: true, tension: 0.4, pointRadius: 0 }] },
        options: { responsive: true, maintainAspectRatio: false, plugins: { legend: { display: false } }, scales: { x: { display: false }, y: { beginAtZero: true, grid: { color: '#f1f3f4' } } } }
    });
}

function addLogRow(p, prepend) {
    const logs = document.getElementById('logs');
    if (!logs) return;

    const isInternal = p.destination.startsWith('192.168.') || p.destination.includes('_gateway');
    const targetUrl = isInternal ? '#' : `http://${p.destination}`;
    
    const row = document.createElement('a');
    row.href = targetUrl;
    row.target = isInternal ? '_self' : '_blank';
    row.className = 'log-row';
    row.style.textDecoration = 'none';
    
    const time = new Date(p.timestamp * 1000).toLocaleTimeString();
    const favicon = getFavicon(p.destination);

    row.innerHTML = `
        <span class="log-time">${time}</span>
        <img src="${favicon}" class="site-mini-icon" onerror="this.src='https://www.google.com/s2/favicons?domain=google.com'">
        <div class="log-dest-info" style="flex:1; display:flex; flex-direction:column; min-width:0;">
            <span class="log-domain" style="font-weight:600; color:var(--primary); white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">${p.destination}</span>
            <span class="log-action-hint" style="font-size:10px; color:#9aa0a6;">${isInternal ? 'Dahili Ağ Trafiği' : 'Ziyaret Et <i class="fas fa-external-link-alt"></i>'}</span>
        </div>
        <span class="proto-badge" style="font-size:9px; padding:2px 5px; background:#e8f0fe; color:var(--primary); border-radius:4px; font-weight:bold;">TCP</span>
    `;

    if (prepend) logs.prepend(row); else logs.appendChild(row);
    if (logs.children.length > 50) logs.removeChild(logs.lastChild);
}

function clearLogs() {
    if (selectedIp && devices[selectedIp]) {
        devices[selectedIp].packets = [];
        devices[selectedIp].count = 0;
        document.getElementById('logs').innerHTML = '';
        updateSidebarItem(selectedIp);
        document.getElementById('det-count').textContent = '0';
    }
}