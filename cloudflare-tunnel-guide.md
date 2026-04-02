# SplitEase Cloudflare Tunnel Setup Guide

This guide describes how to run SplitEase locally and expose it securely to the internet using **Cloudflare Tunnel**, removing all dependencies on the previous VPS deployment.

## 1. Install Cloudflared

Download and install `cloudflared` from the official Cloudflare documents, or use a package manager.
* **macOS**: `brew install cloudflared`
* **Windows**: `winget install cloudflared`
* **Linux**: `wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && sudo dpkg -i cloudflared-linux-amd64.deb`

## 2. Authenticate and Create Tunnel

Run the following command to login to your Cloudflare account. It will open a browser window:
```bash
cloudflared tunnel login
```

Create a new tunnel for your app:
```bash
cloudflared tunnel create splitease-tunnel
```
*Note down the `<TUNNEL_ID>` displayed in the output.*

## 3. Configure the Tunnel

Create a configuration file at `~/.cloudflared/config.yml` (on Linux/Mac) or `%USERPROFILE%\.cloudflared\config.yml` (on Windows). 

Populate it with the following configuration:

```yaml
tunnel: <YOUR_TUNNEL_ID>
credentials-file: /root/.cloudflared/<YOUR_TUNNEL_ID>.json # Or C:\Users\Username\.cloudflared\<YOUR_TUNNEL_ID>.json

ingress:
  # Route traffic for your domain to the Nginx reverse proxy mapped to port 8080 locally
  - hostname: yourdomain.com
    service: http://localhost:8080
  
  # Catch-all rule
  - service: http_status:404
```

*Note: Since the docker-compose setup uses Nginx on port 8080 to serve the Flutter frontend and proxy `/api/*` to the Node.js backend, you only need to point Cloudflare Tunnel to `http://localhost:8080`.*

## 4. Update DNS Settings

Route your domain to the tunnel:
```bash
cloudflared tunnel route dns splitease-tunnel yourdomain.com
```
*(This automatically creates a CNAME record in Cloudflare pointing `yourdomain.com` to `<TUNNEL_ID>.cfargotunnel.com`)*

## 5. Set Environment Variables

Update your `.env` file (copied from `.env.example`) to match your new production domain:

```env
API_URL=https://yourdomain.com/api
CORS_ORIGINS=https://yourdomain.com
```

## 6. Run the Application

1. Start your application locally:
   ```bash
   docker-compose up -d --build
   ```
2. Start the tunnel:
   ```bash
   cloudflared tunnel run splitease-tunnel
   ```

## 7. Verify

You can now open your browser and navigate to:
**[https://yourdomain.com](https://yourdomain.com)**

### Removals Performed
To transition away from the VPS model, we achieved the following cleanups across the repository:
- **Removed GitHub Actions Deploy Job**: The SSH/VPS deployment job utilizing `appleboy/ssh-action` inside `.github/workflows/ci-cd.yml` has been completely stripped out.
- **Removed Localhost IP Hardcoding**: `.env.example` has been updated with instructions to use the live tunneled domain rather than `localhost:3000`.
- **Updated Cookie Policies**: Set `sameSite: 'none'` and `secure: true` on access/refresh cookies in `auth.ts` and `socialAuth.ts` so authentication cookies behave properly across HTTPS proxies via Cloudflare Tunnel.
