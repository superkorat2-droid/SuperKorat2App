// ช่วงเวลารับคำตอบแบบนิเทศ: open_at (วันที่เริ่มทำได้) → deadline (วันหมดเขตส่ง) — migration 102
// ฐานข้อมูลตรวจซ้ำในฟังก์ชันส่งแบบ (ตอบ 'not_open' / 'closed') หน้าเว็บใช้ตัวนี้แค่แสดงผล
//
// สำคัญ: <input type="datetime-local"> ให้ค่า "2026-11-10T14:29" ไม่มีโซนเวลา
// ถ้าส่งตรง ๆ ฐานข้อมูลตีความเป็น UTC → คลาด 7 ชั่วโมง (บั๊กเดิมก่อน migration 102)
// ต้องแปลงผ่าน fromLocalInput / toLocalInput ทุกครั้ง

const pad = n => String(n).padStart(2, '0')

// ISO จากฐานข้อมูล → ค่าในช่อง datetime-local (เวลาเครื่องผู้ใช้)
export function toLocalInput(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  if (isNaN(d)) return ''
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}

// ค่าในช่อง datetime-local → ISO พร้อมโซนเวลา (null ถ้าว่าง)
export function fromLocalInput(str) {
  if (!str) return null
  const d = new Date(str)   // สตริงไม่มีโซนเวลา = ตีความเป็นเวลาเครื่อง
  return isNaN(d) ? null : d.toISOString()
}

// 'not_open' | 'open' | 'closed'
export function formWindow(form, now = new Date()) {
  if (!form) return 'open'
  if (form.status === 'closed') return 'closed'
  if (form.open_at && new Date(form.open_at) > now) return 'not_open'
  if (form.deadline && new Date(form.deadline) < now) return 'closed'
  return 'open'
}

export function fmtThaiDateTime(iso) {
  if (!iso) return ''
  const d = new Date(iso)
  return `${d.toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' })} ${pad(d.getHours())}:${pad(d.getMinutes())} น.`
}

// "เปิดรับ 17 พ.ย. 2569 08:00 น. – 20 พ.ย. 2569 16:30 น." / "หมดเขต …" / "" (ไม่ได้ตั้งวัน)
export function windowText(form) {
  if (!form) return ''
  const o = form.open_at ? fmtThaiDateTime(form.open_at) : ''
  const d = form.deadline ? fmtThaiDateTime(form.deadline) : ''
  if (o && d) return `เปิดรับ ${o} – ${d}`
  if (o) return `เริ่มทำได้ ${o}`
  if (d) return `หมดเขตส่ง ${d}`
  return ''
}

// ข้อความเมื่อฟังก์ชันส่งแบบปฏิเสธเพราะช่วงเวลา (หน้าเปิดค้างไว้แล้วเพิ่งหมดเขต/ยังไม่เปิด)
export function windowErrorText(data) {
  if (data?.error === 'not_open') return `แบบนี้ยังไม่เปิดรับ — เริ่มทำได้ ${fmtThaiDateTime(data.open_at)}`
  if (data?.error === 'closed')   return `หมดเขตส่งแล้วเมื่อ ${fmtThaiDateTime(data.deadline)} — ติดต่อผู้รับผิดชอบเพื่อขยายเวลา คำตอบที่กรอกไว้ยังเก็บอยู่ในเครื่องนี้`
  return ''
}

export const WINDOW_LABEL ={ not_open: 'ยังไม่เปิดรับ', open: 'เปิดรับ', closed: 'หมดเขต' }
export const WINDOW_COLOR = {
  not_open: 'bg-slate-100 text-slate-500',
  open:     'bg-emerald-100 text-emerald-700',
  closed:   'bg-red-100 text-red-600',
}
