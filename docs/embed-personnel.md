# โค้ดฝังทำเนียบบุคลากร (สำหรับเว็บหลักที่เป็น WordPress)

## วิธีใช้

> 💡 **คัดลอกโค้ดสำเร็จรูปได้จาก หลังบ้าน → ตั้งค่าเขต → โค้ดฝังเว็บอื่น**
> มีให้เลือก 3 เวอร์ชัน + ปุ่มดูตัวอย่าง ไม่ต้องมาเปิดไฟล์นี้

วางในบล็อก **"HTML ที่กำหนดเอง"** ของ WordPress (หรือ widget แบบ HTML):

```html
<script src="https://super-korat2-app.vercel.app/embed/personnel.js"></script>
```

เท่านี้จบ — สคริปต์สร้าง iframe ให้เอง ปรับความสูงตามเนื้อหาอัตโนมัติ
**ข้อมูลอ่านสดจากฐานข้อมูลเดียวกับเว็บนิเทศ** แก้ที่ `/dashboard/personnel`
แล้วเว็บหลักเปลี่ยนตามทันทีที่รีเฟรช ไม่ต้องแตะ WordPress อีก

### ตัวเลือก

| attribute | ผล |
|---|---|
| *(ไม่ใส่)* | แสดงทุกคน รวม ผอ.เขต และ รอง ผอ. |
| `data-hide="director"` | ไม่แสดง ผอ.เขต |
| `data-hide="director,deputy"` | ไม่แสดง ผอ.เขต และ รอง ผอ. |
| `data-max-width="900"` | จำกัดความกว้างสูงสุด (px) |
| `data-contact="off"` | **เลิกใช้** — ไม่มีผลแล้ว (ดูหัวข้อ "การ์ดต้องเป็นลิงก์" ข้างล่าง) คงรับไว้เพื่อไม่ให้โค้ดที่วางไปแล้วพัง |

ค่าที่ `data-hide` รับมี `director` · `deputy` · `group_director` เท่านั้น
(whitelist ทั้งฝั่งสคริปต์และฝั่งหน้าเว็บ) ใส่ค่าอื่นจะถูกเมิน

```html
<script src="https://super-korat2-app.vercel.app/embed/personnel.js"
        data-hide="director,deputy" data-max-width="1000"></script>
```

**ทำไมต้องมีเวอร์ชันไม่มี ผอ.เขต:** เว็บหลักของเขตมีหน้าผู้บริหารของตัวเองอยู่แล้ว
ฝังผังที่มี ผอ.เขต/รอง ซ้ำเข้าไปอีกจะซ้ำซ้อน

---

## ทำไมต้องเป็น iframe ไม่ inject HTML เข้าไปตรงๆ

ธีม WordPress มี CSS ครอบกว้าง เช่น `.entry-content img { width:100% !important }`
หรือ `* { line-height:3 }` ถ้า inject markup เข้าไปจะโดนธีมทับจนหน้าตาเพี้ยน
และเพี้ยนไม่เหมือนกันในแต่ละธีม — iframe แยก style ขาดจากกัน จึงเหมือนหน้า
`/personnel` เป๊ะทุกธีม (ทดสอบกับธีมจำลองที่ตั้งใจใส่ CSS ก้าวร้าวแล้ว)

## เรื่องที่ต้องรู้ถ้าจะแก้ต่อ

### 1. URL ของ iframe ต้องเป็น path จริง + hash

```
/embed/personnel#/embed/personnel      ✅
/#/embed/personnel                     ❌ ถูก X-Frame-Options บล็อก
```

เว็บใช้ `createWebHashHistory()` — hash **ไม่ถูกส่งไป server** ฝั่ง server จึงเห็น
`/#/embed/personnel` เป็น `/` เฉยๆ แยก header ตาม path ไม่ได้ และ [vercel.json](../vercel.json)
ส่ง `X-Frame-Options: DENY` ทุกหน้าเพื่อกัน clickjacking → iframe ถูกบล็อกทั้งหมด

ทางออก: ให้ iframe เรียก **path จริง** `/embed/personnel` (rewrite เป็น `index.html`
ตามปกติ) แล้วต่อ **hash** เพื่อบอก router ว่าให้แสดงหน้าไหน
path จริงทำให้ยกเว้น header ได้เฉพาะ `/embed/*`

### 2. กฎ header ใน vercel.json

```
"/((?!embed/).*)"  → X-Frame-Options: DENY        (ทุกหน้ารวม /dashboard)
"/embed/(.*)"      → Content-Security-Policy: frame-ancestors *
```

ต้องเป็น `(?!embed/)` **ไม่ใช่** `(?!embed)` — แบบหลังจะยกเว้นทุก path ที่ขึ้นต้นด้วย
คำว่า embed เช่น `/embedded-guide` ทำให้เสียการป้องกันแบบไม่รู้ตัว

หน้าใน `/embed/` แสดงข้อมูลสาธารณะเท่านั้น ไม่มีฟอร์มล็อกอิน จึงไม่มีอะไรให้ clickjack
ถ้าต้องการเข้มกว่านี้ เปลี่ยน `frame-ancestors *` เป็นโดเมนของเว็บหลักได้เลย เช่น
`frame-ancestors https://www.korat2.go.th`

### 3. การ์ดต้องเป็น **ลิงก์** ไม่ใช่โมดัล (ห้ามเปลี่ยนกลับ)

ในโค้ดฝัง `PersonnelDirectory` รับ prop `linkTo` ทำให้การ์ดเป็น `<a target="_blank">`
ชี้ไปหน้า `/#/personnel` ของเว็บนี้ **ห้ามให้เปิดโมดัลในบริบทที่ฝัง**

เพราะโมดัลเป็น `position: fixed` ซึ่งอ้างอิง viewport ของ **iframe** ไม่ใช่จอผู้ชม
และ `personnel.js` ตั้งความสูง iframe เท่าความสูงเนื้อหาทั้งหมด (production วัดได้
~5,600px) พร้อม `scrolling="no"` → โมดัลไปโผล่กลาง iframe ที่ราว 2,800px
**ต่ำกว่าที่ผู้ชมมองอยู่หลายพันพิกเซล และเลื่อนไปดูไม่ได้** กลายเป็น
"กดแล้วไม่มีอะไรเกิดขึ้น" ส่วนฉากดำ `bg-black/50` ก็ไปคลุมตรงนั้นด้วย ดูเหมือนเว็บเสีย

ผลพลอยได้: ข้อมูลติดต่อ (เบอร์/อีเมล/ไลน์/โซเชียล) อยู่ในโมดัลเท่านั้น การพาไป
หน้าจริงจึงได้ข้อมูลครบกว่า และดึงผู้ชมเข้าเว็บกลุ่มนิเทศด้วย

หน้า `/personnel` ปกติไม่ส่ง `linkTo` จึงยังเปิดโมดัลเหมือนเดิม

### 4. ห้ามวัดความสูงด้วย documentElement.scrollHeight

ค่านั้นถูกดันให้เท่า viewport ของ iframe เสมอเมื่อเนื้อหาสั้นกว่ากรอบ →
iframe **ยืดได้แต่หดไม่ได้** ค้างที่ความสูงเริ่มต้นตลอด
ต้องวัด `getBoundingClientRect().height` ของ element เนื้อหา
(ดู `postHeight()` ใน [EmbedPersonnelView.vue](../src/views/EmbedPersonnelView.vue))

### 5. โครงสร้างการ์ดใช้ร่วมกับหน้า /personnel

`PersonnelDirectory.vue` เป็นตัวเดียวกันทั้งหน้า `/personnel` และหน้าฝัง
**อย่าทำสำเนา** ไม่งั้นแก้หน้าบุคลากรแล้วโค้ดฝังจะไม่ตามไปด้วย
ซึ่งขัดกับจุดประสงค์ของฟีเจอร์นี้ (อัปเดตตามกันอัตโนมัติ)

## ความปลอดภัยของข้อมูล

ข้อมูลอ่านผ่าน view `personnel_public` ซึ่งกรองช่องทางติดต่อตาม `contact_visibility`
ของแต่ละคน **ที่ระดับฐานข้อมูล** ไม่ใช่แค่ซ่อนใน UI
ใครที่ตั้งซ่อนเบอร์ไว้ เบอร์จะเป็น `null` ตั้งแต่ชั้น API — โค้ดฝังจึงเผยแพร่
เฉพาะสิ่งที่เจ้าตัวอนุญาต ดู [migration 0060](../supabase/migrations/20240101000060_personnel_public.sql)
