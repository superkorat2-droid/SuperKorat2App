/**
 * useMapLink — ลิงก์ "นำทาง" ไป Google Maps
 *
 * รูปแบบ dir/?api=1&destination= ลอกจาก navigateTo() ใน PublicSchoolsView.vue
 * ซึ่งใช้งานได้จริงอยู่แล้ว (เปิดแอป Google Maps บนมือถือ / เว็บบนเดสก์ท็อป)
 *
 * ⚠️ อย่าใช้ Static Maps API ทำภาพแผนที่ — ของเดิมใน PublicSchoolsView ส่ง key= เปล่า
 * รูปจึงพังตลอดแล้วถูก @error ซ่อนทิ้ง ถ้าจะใช้จริงต้องเปิด billing บน Google Maps
 * Platform และทำ Edge Function proxy เพิ่ม (ห้ามเอา key ลง VITE_* เด็ดขาด)
 * ภาพแผนที่ในเว็บนี้จึงใช้รูปที่แอดมินอัปเองแทน
 */

/**
 * ไล่ตามลำดับความแม่นยำ — ใช้ได้ตั้งแต่ยังไม่ได้ตั้งค่าอะไรเลย
 * คืน '' เมื่อไม่มีข้อมูลพอ เพื่อให้ผู้เรียกซ่อน UI ทิ้งไปเลย ไม่ใช่โชว์ลิงก์เปล่า
 */
export function directionsUrl({ lat, lng, link, address } = {}) {
  const hasCoord = lat !== null && lat !== undefined && lat !== '' &&
                   lng !== null && lng !== undefined && lng !== ''
  if (hasCoord) {
    return `https://www.google.com/maps/dir/?api=1&destination=${lat},${lng}&travelmode=driving`
  }
  const l = String(link || '').trim()
  if (l) return l

  const a = String(address || '').trim()
  if (a) return `https://www.google.com/maps/dir/?api=1&destination=${encodeURIComponent(a)}`

  return ''
}

/**
 * เบอร์สำหรับ href="tel:" — ต้องเหลือแต่ตัวเลขกับ +
 * ถ้าปล่อยขีดไว้ มือถือบางรุ่นกดแล้วไม่ขึ้นหน้าโทร
 */
export function telHref(phone) {
  return String(phone || '').replace(/[^\d+]/g, '')
}
