// useContentBlocks — ตัวช่วยของ block editor ที่ใช้ร่วมกันระหว่างคลังสื่อกับผลงาน
//
// `_key` เป็นค่าภายในสำหรับ :key ของ v-for เท่านั้น (block ที่โหลดมาจาก DB ไม่มี id)
// ต้องตัดออกก่อนบันทึก ไม่งั้นจะปนลง jsonb ใน DB

/**
 * ใส่ _key ให้ block ที่โหลดมาจาก DB
 *
 * ใช้ UUID ไม่ใช่ `Date.now() + Math.random()` — เลข 1.7e12 กินความละเอียดของ double
 * ไปเกือบหมด เหลือสุ่มจริงแค่ ~4 หลัก มีโอกาสได้ค่าซ้ำ ซึ่งตอนนี้ไม่ใช่แค่ :key ซ้ำ
 * แต่ทำให้ตัวพับบล็อก (useBlockCollapse) พับ 2 บล็อกพร้อมกันด้วย
 */
export function newBlockKey() {
  return crypto.randomUUID()
}

export function withKeys(blocks) {
  return (blocks || []).map(b => ({ ...b, _key: newBlockKey() }))
}

/** ตัด _key ออกก่อนบันทึก */
export function stripKeys(blocks) {
  return (blocks || []).map(({ _key, ...b }) => b)
}

/** ดึงลิงก์ Drive/embed ตัวแรกจาก blocks — ใช้เติม field หลักของสื่อ/ผลงานอัตโนมัติ */
export function firstBlockUrl(blocks, type) {
  return (blocks || []).find(b => b.type === type && b.url?.trim())?.url?.trim() || ''
}
