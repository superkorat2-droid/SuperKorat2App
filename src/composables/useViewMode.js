// useViewMode — สลับมุมมองการ์ด/รายการ และจำค่าที่ผู้ใช้เลือกไว้
import { ref, watch } from 'vue'

/**
 * คลาสสำหรับกริดการ์ดที่ "แถวสุดท้ายอยู่กลาง" เมื่อการ์ดไม่เต็มแถว
 *
 * ใช้ flex-wrap + justify-center ไม่ใช่ CSS grid — grid จะดันการ์ดที่เหลือไปชิดซ้าย
 * เสมอ ทำให้แถวสุดท้ายที่มีการ์ด 1-2 ใบดูโหลง (pattern เดียวกับ PersonnelDirectory
 * และ YoutubeCardGrid ที่ทำไว้ก่อนหน้า)
 *
 * ความกว้างคิดจากสูตร (100% - (n-1) × gap) / n โดย gap-4 = 1rem
 * ต้องเขียนเป็นสตริงตรงๆ ห้ามประกอบด้วยตัวแปร ไม่งั้น Tailwind JIT purge ทิ้ง
 * (Tailwind สแกนไฟล์ .js ด้วย ตาม content glob ของโปรเจค)
 */
export const CARD_WRAP = 'flex flex-wrap justify-center gap-4'
export const CARD_ITEM =
  'w-[calc(50%-0.5rem)] sm:w-[calc(33.333%-0.667rem)] lg:w-[calc(25%-0.75rem)]'
/** สำหรับหน้าที่อยากได้ 5 คอลัมน์บนจอใหญ่ (คลังสื่อเดิมเป็น xl:grid-cols-5) */
export const CARD_ITEM_5 =
  'w-[calc(50%-0.5rem)] sm:w-[calc(33.333%-0.667rem)] lg:w-[calc(25%-0.75rem)] xl:w-[calc(20%-0.8rem)]'

export const VIEW_MODES = [
  { value: 'card', label: 'การ์ด' },
  { value: 'list', label: 'รายการ' },
]

/**
 * @param {string} key คีย์ใน localStorage — แยกต่อหน้า เพื่อให้จำแยกกันได้
 * @param {'card'|'list'} fallback
 */
export function useViewMode(key, fallback = 'card') {
  const storageKey = `viewmode_${key}`
  let initial = fallback
  try {
    const saved = localStorage.getItem(storageKey)
    if (saved === 'card' || saved === 'list') initial = saved
  } catch { /* localStorage ถูกปิด (โหมดส่วนตัว/iframe บางเบราว์เซอร์) — ใช้ค่าเริ่มต้น */ }

  const mode = ref(initial)
  watch(mode, v => {
    try { localStorage.setItem(storageKey, v) } catch { /* เขียนไม่ได้ก็ไม่เป็นไร */ }
  })
  return mode
}
