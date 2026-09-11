/**
 * useImagePipeline — เตรียมรูปจากมือถือก่อนอัปโหลด
 *
 * ปัญหาที่ตัวนี้แก้ (เจอจริงกับงานถ่ายรูปหน้างาน):
 *   1. รูปแนวตั้งจากมือถือ "ตะแคง" — ไฟล์เก็บเป็นแนวนอนแล้วแปะป้าย EXIF บอกให้หมุน
 *      พอวาดลง canvas ตรง ๆ ป้ายนั้นถูกทิ้ง รูปเลยล้ม → แก้ด้วย imageOrientation:'from-image'
 *   2. ไฟล์ใหญ่เกินเพดาน — มือถือถ่าย 3-8 MB แต่ PHP host รับไม่เกิน 5 MB
 *   3. HEIC ของ iPhone — Chrome/Android/คอมถอดรหัสไม่ออก ต้องบอกวิธีแก้ ไม่ใช่แค่ error เปล่า
 *
 * ขนาดที่เลือก 1600px / JPEG 0.82: รายงาน A4 วางรูป 2-3 ใบต่อแถว กว้างใบละ ~8 ซม.
 * ที่ 200 dpi ต้องการ ~630px — 1600px จึงเหลือเฟือแม้ครอบแล้ว และได้ไฟล์ราว 400 KB
 */

export const MAX_EDGE = 1600
export const JPEG_QUALITY = 0.82

/** ไฟล์ที่เบราว์เซอร์ทั่วไปถอดรหัสได้แน่ ๆ */
const SAFE_TYPES = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/bmp']

export class ImageDecodeError extends Error {
  constructor(message, kind) {
    super(message)
    this.name = 'ImageDecodeError'
    this.kind = kind   // 'heic' | 'unsupported'
  }
}

const HEIC_HELP =
  'ไฟล์นี้เป็นรูปแบบ HEIC ของ iPhone ซึ่งเบราว์เซอร์เปิดไม่ได้\n' +
  'แก้โดยไปที่ ตั้งค่า → กล้อง → รูปแบบ → เลือก "รองรับสูงสุด" แล้วถ่ายใหม่\n' +
  'หรือเลือกรูปจากแอป "รูปภาพ" แทนการเลือกผ่านแอป "ไฟล์"'

function looksLikeHeic(file) {
  const t = (file.type || '').toLowerCase()
  const n = (file.name || '').toLowerCase()
  return t.includes('heic') || t.includes('heif') || /\.(heic|heif)$/.test(n)
}

/**
 * ถอดรหัสรูปพร้อมหมุนตาม EXIF ให้เรียบร้อย
 * createImageBitmap เร็วกว่าและคุม orientation ได้ตรง ๆ — Safari เก่าที่ไม่รองรับ
 * option นี้จะตกไปใช้ <img> ซึ่งเบราว์เซอร์รุ่นใหม่หมุนให้เองอยู่แล้ว
 */
async function decode(file) {
  if (typeof createImageBitmap === 'function') {
    try {
      return await createImageBitmap(file, { imageOrientation: 'from-image' })
    } catch {
      // ตกไปทาง <img> ข้างล่าง
    }
  }
  const url = URL.createObjectURL(file)
  try {
    const img = new Image()
    img.src = url
    await img.decode()
    return img
  } finally {
    // ปล่อยทีหลังเล็กน้อยให้ canvas วาดเสร็จก่อนในเบราว์เซอร์ที่ decode แบบ lazy
    setTimeout(() => URL.revokeObjectURL(url), 10_000)
  }
}

function toBlob(canvas, type, quality) {
  return new Promise((resolve, reject) => {
    canvas.toBlob(b => (b ? resolve(b) : reject(new Error('แปลงรูปไม่สำเร็จ'))), type, quality)
  })
}

/**
 * ย่อ + แปลงเป็น JPEG + หมุนตาม EXIF
 * @returns {Promise<{blob: Blob, w: number, h: number, before: number, after: number}>}
 */
export async function prepareImage(file, { maxEdge = MAX_EDGE, quality = JPEG_QUALITY } = {}) {
  if (looksLikeHeic(file)) throw new ImageDecodeError(HEIC_HELP, 'heic')
  if (file.type && !SAFE_TYPES.includes(file.type.toLowerCase()) && !file.type.startsWith('image/')) {
    throw new ImageDecodeError(`ไฟล์ "${file.name}" ไม่ใช่รูปภาพ`, 'unsupported')
  }

  let src
  try {
    src = await decode(file)
  } catch {
    throw new ImageDecodeError(
      looksLikeHeic(file) ? HEIC_HELP : `เปิดไฟล์ "${file.name}" ไม่ได้ ลองบันทึกเป็น JPG แล้วอัปใหม่`,
      'unsupported',
    )
  }

  const sw = src.width, sh = src.height
  // ไม่ขยายรูปที่เล็กกว่าเพดานอยู่แล้ว — ขยายมีแต่ทำให้ไฟล์ใหญ่ขึ้นโดยไม่ได้รายละเอียดเพิ่ม
  const scale = Math.min(1, maxEdge / Math.max(sw, sh))
  const w = Math.round(sw * scale)
  const h = Math.round(sh * scale)

  const canvas = document.createElement('canvas')
  canvas.width = w
  canvas.height = h
  const ctx = canvas.getContext('2d')
  ctx.imageSmoothingQuality = 'high'
  // JPEG ไม่มีพื้นโปร่ง — ถ้าต้นฉบับเป็น PNG โปร่งใสจะกลายเป็นดำถ้าไม่รองพื้นขาวก่อน
  ctx.fillStyle = '#ffffff'
  ctx.fillRect(0, 0, w, h)
  ctx.drawImage(src, 0, 0, w, h)
  if (src.close) src.close()

  const blob = await toBlob(canvas, 'image/jpeg', quality)
  return { blob, w, h, before: file.size, after: blob.size }
}

export function formatBytes(n) {
  const b = Number(n) || 0
  if (b >= 1048576) return (b / 1048576).toFixed(1) + ' MB'
  if (b >= 1024) return Math.round(b / 1024) + ' KB'
  return b + ' B'
}

/** ข้อความสรุปให้ผู้ใช้เห็นว่าย่อไปเท่าไร เช่น "8.1 MB → 412 KB" */
export function shrinkLabel(before, after) {
  return `${formatBytes(before)} → ${formatBytes(after)}`
}
