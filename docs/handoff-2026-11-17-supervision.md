# บันทึกส่งต่องาน — ระบบแบบนิเทศ (11–17 พ.ย. 2569)

> ต่อจาก `docs/handoff-2026-11-10-supervision.md` · สถานะ: **เสร็จครบ ขึ้นเว็บจริงแล้วทุกงาน ไม่มีงานค้าง**

## สรุปสถานะ

| | |
|---|---|
| commit ล่าสุดบนเว็บจริง | `83c2bd3` (`main` = `superkorat2app/main`) |
| migration บน production | ครบถึง **0102** |
| Vercel | deploy สำเร็จทุกครั้ง |
| ข้อมูลบน production (17 พ.ย.) | แบบนิเทศ 7 · ชุดคำตอบ 1 · คำตอบ 21 — ตรวจก่อน/หลังทุก migration ไม่หาย |

## งานที่ขึ้นเว็บจริงแล้ว

| วันที่ | commit | migration | งาน |
|---|---|---|---|
| 11 พ.ย. | `b4b892d` | 0100 | ธีมสี 8 ชุด · ขนาดการแสดงผล (ปกติ/ใหญ่/ใหญ่มาก) · รายการเอกสารหลักฐานให้ผู้ตอบติ๊ก/พิมพ์เอง |
| 11 พ.ย. | `8487baf` | — | ผู้จัดการ "ปลดล็อกให้ส่งใหม่" + คืนสถานะ (ใช้ `is_complete` เดิม) |
| 11 พ.ย. | `a1b878c` | — | แดชบอร์ดผลลัพธ์: ตัวกรองอำเภอ/ศูนย์ · สรุปรายศูนย์ · คะแนนรายโรง/รายหมวด · หน้าแบบบุคคล · Excel 4 ชีต |
| 11 พ.ย. | `ebba953` | — | ปุ่ม "จำเป็น / ไม่บังคับ" ของรายการเอกสารหลักฐาน |
| 11 พ.ย. | `f400b16` | 0101 | แอดมินจัดลำดับแบบนิเทศในหน้าแรก (แบบใหม่ที่ยังไม่จัดขึ้นบนสุด) |
| 17 พ.ย. | `83c2bd3` | 0102 | วันที่เริ่มทำได้ + วันหมดเขตส่ง**ปิดรับอัตโนมัติ** · ปุ่ม "📅 ปรับวัน" · **แก้เวลาคลาด 7 ชม.** · ชื่อสำนักงานใต้ปุ่มส่ง |

## จุดที่ต้องรู้ก่อนแก้โค้ดต่อ

### 1) ช่องวันเวลา `datetime-local` ต้องแปลงโซนเวลาเสมอ
- ค่าจากช่องเป็น `"2026-11-10T14:29"` ไม่มีโซนเวลา ส่งตรง ๆ ฐานข้อมูลตีความเป็น **UTC** → คลาด 7 ชั่วโมง
- แบบนิเทศใช้ `toLocalInput()` / `fromLocalInput()` ใน `src/composables/useSupervisionWindow.js` แล้ว
- **ยังมีหน้าอื่นที่ส่งตรงอยู่** เช่น `src/views/admin/AdminDmcPeriodsView.vue` (กำหนดส่ง DMC) — ถ้าจะใช้เวลาไปตรวจปิดรับ ต้องแก้แบบเดียวกัน
- migration 0102 แก้ค่าเดิมของแบบนิเทศแล้ว (ทำในบล็อกเดียวกับการเพิ่ม `open_at` กันเลื่อนซ้ำ)

### 2) ไฟล์ JavaScript หลักใกล้เพดาน
- `index.js` = **2.03 MB** เพดาน precache ของ PWA = 2.10 MB (2 MiB) → เหลือประมาณ 66 KB
- เกินเมื่อไร `npx vite build` จะ **error** (ข้อความ "✓ built in" ขึ้นก่อน error — ต้องอ่านให้จบ) และ Vercel จะ deploy ไม่ผ่าน
- วิธีแก้: เปลี่ยนหน้าแอดมินที่หนักใน `src/router/index.js` เป็น `() => import(...)` (มีตัวอย่าง: หน้าแก้ไข/ผลลัพธ์แบบนิเทศ, /works, /awards)

### 3) โครงข้อมูลที่เพิ่มใหม่
| ที่เก็บ | ความหมาย |
|---|---|
| `supervision_forms.theme`, `display_size` | ธีม/ขนาด ค่าเริ่มต้น `site` / `normal` = หน้าตาเดิม |
| `supervision_forms.home_order` | ลำดับหน้าแรก (null = ยังไม่จัด → ขึ้นบนสุด) |
| `supervision_forms.open_at`, `deadline` | ช่วงรับคำตอบ (null = ไม่จำกัด) — ฟังก์ชันส่งแบบตอบ `not_open` / `closed` |
| `supervision_questions.settings.evidence_items` / `evidence_allow_custom` / `evidence_items_required` | รายการเอกสารของผู้สร้าง |
| `supervision_answers.evidence_items` | เอกสารที่ผู้ตอบเลือก |
| `supervision_responses.is_complete = false` | = ถูกปลดล็อกให้ส่งใหม่ (คำตอบเดิมเก็บเป็นประวัติ) |

### 4) ไฟล์กลางที่ใช้ร่วม
- `src/composables/useSupervisionScore.js` — สูตรคะแนน (คำตอบว่างไม่นับ) ใช้ทั้งหน้าผลลัพธ์และ Excel
- `src/composables/useSupervisionExport.js` — Excel หลายชีต
- `src/composables/useSupervisionTheme.js` — ธีม/ขนาด
- `src/composables/useSupervisionWindow.js` — ช่วงเวลารับคำตอบ + แปลงเวลา
- `src/components/supervision/EvidenceItemsPicker.vue`, `SupervisionAnswerEditModal.vue`
- หน้าผลลัพธ์: `allResponses` = ทั้งหมด, `responses` = กรองแล้ว — อะไรที่ต้องเห็นทั้งเขต (เช่น ตรวจว่าส่งใหม่แล้ว) ใช้ `allResponses`

### 5) การรัน migration บน production
- ฟังก์ชันส่งแบบ (`submit_supervision_*`) และ `get_supervision_list_public` ถูกแก้ทุกรอบ — **นิยามล่าสุดอยู่ใน migration 0102** ให้ลอกจากไฟล์นั้น (หรือ `pg_get_functiondef` บน production)
- ทุกครั้ง: นับแบบ/ชุดคำตอบ/คำตอบ ก่อนและหลัง · รัน migration ก่อน push โค้ดเสมอ

## เรื่องเครื่อง/บัญชี
- `git push` เฉย ๆ ขึ้นเว็บจริง (upstream = `superkorat2app`) · `origin` = repo เก่า
- Supabase CLI ต้องล็อกอินบัญชีของโปรเจคนี้ (เห็น `superkorat2app` ref `yrdtqwqyqtrefjtutzzf`)
- ใช้ CLI ที่ติดตั้งในเครื่อง ไม่ใช้ `npx supabase` (รุ่น 3.x อ่าน `config.toml` นี้ไม่ได้)
- รหัสทดสอบ local: `admin@local.dev` / `LocalTest#12345`
- ใน shell ของ Claude Code: สคริปต์ยาวที่มี backtick ใน heredoc มักพัง → เขียนลงไฟล์ก่อนแล้วค่อยรัน

## วิธีเริ่มทำต่อ
```
git pull
supabase start
supabase migration up      # อย่าใช้ db reset ถ้ามีข้อมูลจริงที่กู้มาไว้
npm run dev
```
หน้าแบบนิเทศ: http://localhost:5173/#/dashboard/supervision
