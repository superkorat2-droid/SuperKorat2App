// useYoutubeGrid — ตัวช่วยของการ์ดลิงก์ YouTube (ใช้ร่วมกันทั้งหน้าสาธารณะและ admin)

/** ดึง video id จาก URL ทุกรูปแบบที่ YouTube ใช้ — คืน '' ถ้าไม่ใช่ลิงก์ YouTube */
export function youtubeId(url) {
  if (!url) return ''
  const s = String(url).trim()
  // watch?v= / youtu.be/ / embed/ / shorts/ / live/
  const m = s.match(/(?:youtube\.com\/(?:watch\?(?:.*&)?v=|embed\/|shorts\/|live\/)|youtu\.be\/)([A-Za-z0-9_-]{11})/)
  if (m) return m[1]
  // วางแค่ id มาเฉยๆ ก็รับ
  return /^[A-Za-z0-9_-]{11}$/.test(s) ? s : ''
}

/** รูปปกวิดีโอ — hqdefault มีทุกคลิป (maxres บางคลิปไม่มีแล้วขึ้นภาพเทา) */
export function youtubeThumb(url) {
  const id = youtubeId(url)
  return id ? `https://img.youtube.com/vi/${id}/hqdefault.jpg` : ''
}

/** ตัวเลือกจำนวนคอลัมน์ที่ให้ admin เลือก */
export const COL_OPTIONS = [1, 2, 3, 4, 6, 8]

/**
 * ความกว้างการ์ดต่อจำนวนคอลัมน์ (ใช้กับ flex-wrap gap-4 = 16px)
 * สูตร: 100%/n - gap*(n-1)/n
 * ต้องเขียนเป็น class เต็มคำ ไม่ต่อ string ไม่งั้น Tailwind JIT จะ purge ทิ้ง
 */
export const COL_WIDTH_CLASS = {
  1: 'w-full',
  2: 'w-full sm:w-[calc(50%-8px)]',
  3: 'w-full sm:w-[calc(50%-8px)] md:w-[calc(33.333%-11px)]',
  4: 'w-full sm:w-[calc(50%-8px)] md:w-[calc(25%-12px)]',
  6: 'w-[calc(50%-8px)] sm:w-[calc(33.333%-11px)] md:w-[calc(16.666%-14px)]',
  8: 'w-[calc(50%-8px)] sm:w-[calc(25%-12px)] md:w-[calc(12.5%-14px)]',
}
