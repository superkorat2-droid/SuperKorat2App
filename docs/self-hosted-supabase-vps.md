# Self-Hosted Supabase บน VPS (Docker)

## ข้อดีเทียบกับ Supabase Cloud

| | Cloud (Free) | Cloud (Pro) | Self-Hosted VPS |
|---|---|---|---|
| Storage | 1 GB | 8 GB + $0.021/GB | ✅ ตามขนาด disk |
| DB | 500 MB | 8 GB | ✅ ตามขนาด disk |
| File size | 50 MB | 5 GB | ✅ กำหนดเอง |
| ราคา | ฟรี | $25/เดือน | VPS ~$10–20/เดือน |
| Video upload | จำกัด | จำกัด | ✅ ไม่จำกัด |

---

## VPS Requirements

| Spec | Minimum | แนะนำ |
|---|---|---|
| CPU | 2 vCPU | 4 vCPU |
| RAM | 4 GB | 8 GB |
| Storage | 50 GB SSD | 100 GB+ SSD |
| OS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |

**ผู้ให้บริการแนะนำ (ราคาถูก + เสถียร):**
- Hetzner Cloud (ยุโรป, $5–15/เดือน)
- Vultr / DigitalOcean ($12–24/เดือน)
- AWS Lightsail / Oracle Cloud Free Tier

---

## ขั้นตอนติดตั้ง

### 1. ติดตั้ง Docker บน VPS

```bash
# Ubuntu 22.04
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
sudo systemctl enable docker
```

### 2. Clone Supabase self-hosted

```bash
git clone --depth 1 https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env
```

### 3. แก้ .env (สำคัญมาก)

```env
############
# Secrets — CHANGE ALL OF THESE
############
POSTGRES_PASSWORD=your-super-secret-postgres-password
JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...   # generate ใหม่
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...  # generate ใหม่

############
# Site URL
############
SITE_URL=https://yourdomain.com
API_EXTERNAL_URL=https://api.yourdomain.com  # หรือ https://yourdomain.com:8000

############
# Dashboard
############
DASHBOARD_USERNAME=admin
DASHBOARD_PASSWORD=your-dashboard-password

############
# Email (ใช้ SMTP จริง)
############
SMTP_ADMIN_EMAIL=admin@yourdomain.com
SMTP_HOST=smtp.gmail.com  # หรือ Resend, Mailgun
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
SMTP_SENDER_NAME=ชื่อระบบ
```

#### Generate JWT Keys ใหม่:
```bash
# ติดตั้ง tool
npm install -g @supabase/generate-keys

# Generate
supabase-generate-keys
```

### 4. แก้ storage limit ใน docker/volumes/api/kong.yml

ไม่ต้องแก้ kong.yml — แก้ใน storage service config แทน:

```bash
# แก้ STORAGE_FILE_SIZE_LIMIT ใน .env
STORAGE_FILE_SIZE_LIMIT=5368709120  # 5 GB
```

หรือแก้ใน `docker/docker-compose.yml` ส่วน `storage`:
```yaml
storage:
  environment:
    FILE_SIZE_LIMIT: 5368709120  # 5 GB
```

### 5. รัน Supabase

```bash
docker compose up -d

# ตรวจสอบ
docker compose ps
docker compose logs -f
```

---

## ตั้งค่า Nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/supabase
server {
    server_name api.yourdomain.com;

    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';

        # สำคัญ: เพิ่ม limit สำหรับ video upload
        client_max_body_size 5000M;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
}
```

```bash
# SSL ด้วย Let's Encrypt (ฟรี)
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d api.yourdomain.com
```

---

## Migrate โปรเจกต์นี้ไป Self-Hosted

### 1. แก้ .env.local ของโปรเจกต์

```env
VITE_SUPABASE_URL=https://api.yourdomain.com
VITE_SUPABASE_ANON_KEY=eyJ...  # anon key ที่ generate ใหม่
VITE_SUPABASE_SERVICE_KEY=eyJ...  # service key ที่ generate ใหม่
```

### 2. Push migrations

```bash
# Link กับ self-hosted
npx supabase link --project-ref localhost --supabase-url https://api.yourdomain.com

# Push migrations ทั้งหมด
npx supabase db push --db-url postgresql://postgres:PASSWORD@yourdomain.com:5432/postgres
```

### 3. Import ข้อมูล (ถ้ามีจาก Cloud)

```bash
# Export จาก Cloud
npx supabase db dump -f dump.sql

# Import เข้า self-hosted
psql postgresql://postgres:PASSWORD@yourdomain.com:5432/postgres < dump.sql
```

### 4. อัปเดต Storage buckets

เข้า Supabase Studio ที่ `https://api.yourdomain.com` แล้วสร้าง buckets:
- `banners` — public, file limit: 500MB
- `images` — public, file limit: 50MB
- `documents` — private, file limit: 100MB
- `dmc-files` — private, file limit: 50MB
- `supervision-evidence` — public, file limit: 100MB

หรือ run migration ทั้งหมดผ่าน `npx supabase db push` จะสร้างให้อัตโนมัติ

---

## Video Upload — ไม่จำกัดแล้ว

หลัง self-hosted ตั้งค่า `FILE_SIZE_LIMIT=5368709120` (5 GB):

```bash
# แก้ใน AdminBannersView.vue
const MAX_MB = 500  # หรือ 1000 แล้วแต่ต้องการ
```

และ update bucket limit ผ่าน SQL:
```sql
UPDATE storage.buckets
SET file_size_limit = 5368709120  -- 5 GB
WHERE id = 'banners';
```

---

## Backup อัตโนมัติ

```bash
# /etc/cron.daily/supabase-backup
#!/bin/bash
DATE=$(date +%Y%m%d)
pg_dump postgresql://postgres:PASSWORD@localhost:5432/postgres \
  | gzip > /backups/db_${DATE}.sql.gz

# เก็บ 7 วันล่าสุด
find /backups -name "*.gz" -mtime +7 -delete
```

---

## Checklist ก่อน Go Live

- [ ] เปลี่ยน JWT_SECRET, POSTGRES_PASSWORD ทั้งหมด
- [ ] ตั้ง SSL certificate
- [ ] ตั้ง SMTP จริง
- [ ] Backup strategy
- [ ] ย้าย Service Role Key ออกจาก frontend → Edge Function
- [ ] ตั้ง Rate limiting บน Nginx
- [ ] Monitor disk space (วิดีโอกิน disk เร็ว)
