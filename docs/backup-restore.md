# สำรองข้อมูล Supabase และวิธีกู้คืน

## สำรองข้อมูล

```powershell
npm run backup
```

ได้โฟลเดอร์ `D:\SupabaseBackup\superkorat2app\<วันเวลา>\` หน้าตาแบบนี้

| ไฟล์/โฟลเดอร์ | คืออะไร |
| --- | --- |
| `db/roles.sql` | role ที่สร้างเอง |
| `db/schema.sql` | โครงสร้างทั้งหมด ตาราง RLS ฟังก์ชัน trigger |
| `db/data.sql` | ข้อมูลทุกแถว **รวมบัญชีผู้ใช้ `auth.users` และแฮชรหัสผ่าน** |
| `storage/` | ไฟล์จริงทุกไฟล์ในทุก bucket |
| `project/` | migrations + edge functions + config.toml ณ commit นั้น |
| `MANIFEST.txt` | สรุปว่าสำรองเมื่อไหร่ commit ไหน ได้กี่ไฟล์ |

> **`db/data.sql` เป็นความลับ** อย่า commit อย่าอัปขึ้น Drive สาธารณะ
> สคริปต์จึงเขียนออกนอก repo ไว้ที่ `D:\SupabaseBackup\` ตั้งแต่แรก

ควรรันก่อนทำอะไรเสี่ยง ๆ ทุกครั้ง (แก้ migration ใหญ่ ๆ, ลบข้อมูลเป็นชุด) และรันประจำอย่างน้อยเดือนละครั้ง

## สิ่งที่ backup **ไม่มี** ต้องจดเองแยกต่างหาก

- **ค่าจริงของ edge function secrets** — CLI ให้ดูได้แค่ชื่อ ต้องไปคัดลอกจาก Dashboard เก็บไว้เอง
  (`ADMIN_SECRET_KEY`, `GOOGLE_API_KEY`, `UPLOAD_API_SECRET`, `UPLOAD_API_URL`, ฯลฯ)
- **ตั้งค่าใน Dashboard** — provider ล็อกอิน, redirect URL, เทมเพลตอีเมล
- **ไฟล์ที่ไม่ได้อยู่บน Supabase** — รูป/วิดีโอบน PHP host (`supervision.korat2.go.th`) และไฟล์บน Google Drive
  สองอย่างนี้ต้องสำรองแยก (FTP / Drive)

## กู้คืนขึ้นโปรเจค Supabase ใหม่

ใช้ตอนโปรเจคเดิมโดนลบ โดนพัก หรือย้ายไปบัญชีอื่น

1. สร้างโปรเจคใหม่บน Supabase แล้วผูกเข้ากับเครื่อง

   ```powershell
   supabase link --project-ref <ref-ใหม่>
   ```

2. เอา connection string ของโปรเจคใหม่จาก Dashboard → Connect → URI แล้วยิง 3 ไฟล์ตามลำดับ
   (ในเครื่องไม่ได้ลง `psql` จึงยืมจาก docker image แทน)

   ```powershell
   $DB = "postgresql://postgres.<ref>:<password>@aws-1-ap-northeast-1.pooler.supabase.com:5432/postgres"
   $BK = "D:\SupabaseBackup\superkorat2app\<วันเวลา>"

   docker run --rm -v "${BK}\db:/b" postgres:17 psql "$DB" -f /b/roles.sql
   docker run --rm -v "${BK}\db:/b" postgres:17 psql "$DB" -f /b/schema.sql
   docker run --rm -v "${BK}\db:/b" postgres:17 psql "$DB" --single-transaction -f /b/data.sql
   ```

   ตาราง `profiles` มี foreign key วนกัน ถ้าติดตอนโหลด data ให้เติม `--disable-triggers`
   (ต้องต่อด้วย user ที่เป็น superuser) หรือโหลด `data.sql` ซ้ำอีกรอบให้แถวที่ค้างลงครบ

3. อัปไฟล์ storage กลับขึ้นไป

   `data.sql` พา **แถวใน `storage.objects` กลับมาด้วย** ทั้งที่ตัวไฟล์จริงยังไม่มี ถ้าอัปเลยจะโดนปฏิเสธว่าซ้ำ
   ต้องล้างแถวทิ้งก่อน แล้วให้ตอนอัปสร้างแถวใหม่เอง (bucket ยังอยู่ ไม่ต้องสร้างใหม่)

   ```sql
   -- รันใน SQL Editor ของ Dashboard
   TRUNCATE storage.objects CASCADE;
   ```

   ```powershell
   powershell -File scripts\restore-storage.ps1 -BackupDir $BK -Linked
   ```

   > อย่าใช้ `supabase storage cp -r` ตรง ๆ บนวินโดวส์ มันจะซ้อนชื่อโฟลเดอร์เป็น `/images/images/...`
   > และส่งโฟลเดอร์ย่อยเป็น backslash จนโดน `400 InvalidKey`
   > สคริปต์ข้างบนจึงอัปทีละไฟล์พร้อมระบุ key เอง

4. ตั้ง secrets กลับ แล้ว deploy edge functions

   ```powershell
   supabase secrets set ADMIN_SECRET_KEY=... GOOGLE_API_KEY=... UPLOAD_API_SECRET=... UPLOAD_API_URL=...
   supabase functions deploy
   ```

5. แก้ `.env.production` ให้ชี้ URL + publishable key ของโปรเจคใหม่ แล้ว deploy เว็บใหม่
   (อย่าลืมแก้ env บน Vercel ด้วย ไม่ใช่แค่ไฟล์ในเครื่อง)

## ซ้อมกู้คืนลงเครื่อง (ทำจริงแล้ว 3 ส.ค. 69 ผ่านทุกขั้น)

ไม่แตะ production เลย ใช้พิสูจน์ว่า backup กู้ได้จริง **ข้อมูลใน local เดิมหายหมด**

```powershell
$BK = "D:\SupabaseBackup\superkorat2app\<วันเวลา>"
$C  = "supabase_db_vue_gas_supabase_superArea"

npm run sb:start
supabase db reset --no-seed          # schema จาก migrations, ไม่รัน seed.sql (ข้อมูลตัวอย่างจะชนกับของจริง)

# ล้างข้อมูลที่ migrations ใส่ไว้ (area_config, pages, storage.buckets ฯลฯ) ไม่งั้นชน primary key
docker cp "scripts\restore-truncate.sql" "${C}:/tmp/truncate.sql"
docker cp "$BK\db\data.sql" "${C}:/tmp/data.sql"
docker exec $C psql -U postgres -d postgres -f /tmp/truncate.sql
docker exec $C psql -U postgres -d postgres -f /tmp/data.sql
powershell -File scripts\restore-storage.ps1 -BackupDir $BK -Local
```

เปิด http://127.0.0.1:54323 ดูข้อมูลใน Studio หรือ `npm run dev` แล้วเปิดเว็บดู

**ต้อง TRUNCATE แบบดักข้อผิดพลาดรายตาราง** เพราะ `storage.buckets_vectors` กับ `storage.vector_indexes`
แม้แต่ user `postgres` ก็ไม่มีสิทธิ์แตะ ถ้าปล่อยให้ error มันจะ rollback การล้างทั้งก้อนโดยไม่บอก
แล้วไปโผล่เป็น duplicate key ตอนโหลด data.sql

error 2 บรรทัดนี้ตอนโหลด **ไม่ต้องสนใจ** สองตารางนั้นว่างเปล่าอยู่แล้ว

```
ERROR:  permission denied for table buckets_vectors
ERROR:  permission denied for table vector_indexes
```

**ล็อกอินใน local หลังกู้ ต้องใช้รหัสผ่านของบัญชีจริงบน production** เพราะ `auth.users` ถูกทับด้วยของจริง
รหัสทดสอบ local เดิมใช้ไม่ได้แล้ว

## ถ้ากังวลเรื่องโดนพักโปรเจค

แพ็กเกจฟรีจะ **พักโปรเจคเมื่อไม่มีการใช้งานติดกัน 1 สัปดาห์** (กดปลุกคืนได้เอง ข้อมูลไม่หาย)
และ **ไม่มี backup อัตโนมัติให้** — daily backup มีเฉพาะแพ็กเกจ Pro
เว็บนี้มีคนเข้าทุกวันอยู่แล้วจึงไม่น่าโดนพัก แต่เพราะไม่มี backup ฝั่งเขาเลย
การรัน `npm run backup` เก็บไว้เองจึงเป็นตาข่ายรองรับเส้นเดียวที่มี

ถ้าอยากย้ายออกไปโฮสต์เองในอนาคต ดู [self-hosted-supabase-vps.md](self-hosted-supabase-vps.md)
