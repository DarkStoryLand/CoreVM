# 04. Cloudflare Global Edge & WAF Integration

## 1. Domain & DNS Architecture

Zone: `darkstoryland.com` (Zone ID: `0c542bad19e6d450b7a12f6009335de1`)  
Account ID: `88598b1604aa5f50c69a66a1549ed743`

### DNS Routing Map

| Name | Type | Target | Proxy Status | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `@` | A | `168.222.2.57` | 🟠 Proxied | Official Landing Page & Web Portal |
| `www` | CNAME | `darkstoryland.com` | 🟠 Proxied | Canonical Web Redirect |
| `play` | A | `168.222.2.57` | 🟠 Proxied | Browser WebClient & WebSocket Canvas (WS On) |
| `bo` | A | `168.222.2.57` | 🟠 Proxied | GM & Staff Administration Back-Office |
| `api` | A | `168.222.2.57` | 🟠 Proxied | REST API, Webhooks, EasySlip Integration |
| `s` | A | `168.222.2.57` | 🔘 DNS Only | Raw Game TCP Sockets (14400, 14600, 18001+) |

---

## 2. Cloudflare SSL/TLS & Edge Optimization

- **SSL Mode**: `Full` (Cloudflare validates origin SSL over port 443 with self-signed certificate).
- **Always Use HTTPS**: Enabled (Auto-upgrades HTTP port 80 requests to HTTPS 443).
- **Minimum TLS Version**: `TLS 1.2` (Enforces modern cipher suites).
- **WebSockets**: Enabled (Required for HTML5 canvas real-time frame streaming on `play.darkstoryland.com`).
- **HTTP/3 (with QUIC)**: Enabled for ultra-low latency mobile and web connections.

---

## 3. Cloudflare Real-IP Restoration in Nginx

When requests pass through Cloudflare Proxy, the origin server sees Cloudflare Anycast IP addresses. Nginx is configured with `set_real_ip_from` blocks to restore client IP addresses from `CF-Connecting-IP`:

```nginx
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 104.16.0.0/13;
set_real_ip_from 104.24.0.0/14;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 131.0.72.0/22;
real_ip_header CF-Connecting-IP;
```
