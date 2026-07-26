// useContentBlocks — ตัวช่วยของ block editor ที่ใช้ร่วมกันระหว่างคลังสื่อกับผลงาน
//
// `_key` เป็นค่าภายในสำหรับ :key ของ v-for เท่านั้น (block ที่โหลดมาจาก DB ไม่มี id)
// ต้องตัดออกก่อนบันทึก ไม่งั้นจะปนลง jsonb ใน DB

/** ใส่ _key ให้ block ที่โหลดมาจาก DB */
export function withKeys(blocks) {
  return (blocks || []).map(b => ({ ...b, _key: Date.now() + Math.random() }))
}

/** ตัด _key ออกก่อนบันทึก */
export function stripKeys(blocks) {
  return (blocks || []).map(({ _key, ...b }) => b)
}

/** ดึงลิงก์ Drive/embed ตัวแรกจาก blocks — ใช้เติม field หลักของสื่อ/ผลงานอัตโนมัติ */
export function firstBlockUrl(blocks, type) {
  return (blocks || []).find(b => b.type === type && b.url?.trim())?.url?.trim() || ''
}
