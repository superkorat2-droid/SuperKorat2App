/**
 * useVisitTracker — บันทึกการเข้าชมหน้าเว็บสาธารณะ
 *
 * ทุกอย่างที่ตัดสินใจได้ฝั่งเซิร์ฟเวอร์ (IP, บอต, กันนับซ้ำ 30 นาที) อยู่ใน RPC
 * `track_visit` แล้ว ที่นี่ทำแค่ 2 อย่างที่เซิร์ฟเวอร์ทำแทนไม่ได้:
 *   1. แยกชนิดอุปกรณ์จาก navigator (UA ฝั่งเซิร์ฟเวอร์แยกมือถือ/แท็บเล็ตได้ไม่แม่น)
 *   2. บอกว่า path ไหนถูกเปิด — hash router ทำให้เซิร์ฟเวอร์เห็นแต่ "/" เสมอ
 *
 * ยิงแบบ fire-and-forget ห้าม await ในตัว router guard เด็ดขาด ไม่งั้นการ
 * เปลี่ยนหน้าจะหน่วงรอ network ทุกครั้ง
 */
import { supabase } from '../supabase'

/** หน้าหลังบ้าน + iframe ที่ฝังในเว็บอื่น ไม่นับรวมกับสถิติสาธารณะ
 *  (RPC กันซ้ำอีกชั้นอยู่แล้ว ที่นี่กันไว้เพื่อไม่ต้องยิง network ทิ้งเปล่า) */
const SKIP = /^\/(dashboard|school|embed|login|register)(\/|$)/

/** กันยิงซ้ำภายในแท็บเดียวกัน — RPC กัน 30 นาทีอยู่แล้ว แต่ไม่ต้องให้ถึงมือมัน */
const seen = new Map()
const SAME_PATH_COOLDOWN = 30 * 60 * 1000

/**
 * มือถือ/แท็บเล็ต/คอมพิวเตอร์
 * iPadOS 13+ ปลอม UA เป็น Mac จึงต้องดู maxTouchPoints ประกอบ ไม่งั้นแท็บเล็ต
 * ทั้งหมดจะไปกองอยู่ฝั่ง desktop
 */
export function detectDevice() {
  if (typeof navigator === 'undefined') return 'desktop'
  const ua = navigator.userAgent || ''
  const touch = (navigator.maxTouchPoints || 0) > 1

  if (/iPad/i.test(ua) || (/Macintosh/i.test(ua) && touch)) return 'tablet'
  if (/Tablet|PlayBook|Silk/i.test(ua)) return 'tablet'
  if (/Android/i.test(ua) && !/Mobile/i.test(ua)) return 'tablet'   // Android ที่ไม่มี "Mobile" = แท็บเล็ต
  if (/Mobi|iPhone|iPod|Windows Phone|IEMobile|BlackBerry|Opera Mini/i.test(ua)) return 'mobile'
  return 'desktop'
}

/** ตัด query/hash ออก เหลือ path ล้วน — /news?page=2 กับ /news ต้องเป็นหน้าเดียวกัน */
function cleanPath(fullPath) {
  return String(fullPath || '').split('?')[0].split('#')[0] || '/'
}

export function trackVisit(fullPath, title) {
  const path = cleanPath(fullPath)
  if (!path.startsWith('/') || SKIP.test(path)) return

  const now = Date.now()
  if (now - (seen.get(path) || 0) < SAME_PATH_COOLDOWN) return
  seen.set(path, now)

  // ไม่ await และกลืน error ทิ้ง — สถิติพังไม่ควรทำให้หน้าเว็บพัง
  supabase.rpc('track_visit', {
    p_path:   path,
    p_title:  (title || document.title || '').slice(0, 200),
    p_device: detectDevice(),
  }).then(({ error }) => {
    if (error && import.meta.env.DEV) console.warn('[visit] บันทึกไม่สำเร็จ:', error.message)
  })
}

/** ตัวนับสำหรับท้ายเว็บ — คืน {total, today} */
export async function fetchVisitCounter() {
  const { data, error } = await supabase.rpc('get_visit_counter')
  if (error) return null
  return data || null
}
