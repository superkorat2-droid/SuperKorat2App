import { ref } from 'vue'
import { supabase } from '../supabase'

// อัปโหลดรูป/ไฟล์ไปยัง PHP host ของเขต (เช่น supervision.korat2.go.th)
//
// ⚠️ ห้ามยิง upload.php ตรงจากเบราว์เซอร์อีก — เดิมต้องแนบ X-Upload-Secret ซึ่งมาจาก
// VITE_UPLOAD_API_SECRET และ Vite ฝังค่านั้นลงไฟล์ JS ที่ใครก็โหลดได้
// ความลับจึงหลุดสู่สาธารณะ ใครก็อัปโหลด/ลบไฟล์บนเซิร์ฟเวอร์เขตได้โดยไม่ต้องล็อกอิน
// ตอนนี้ทุกคำสั่งผ่าน Edge Function `media-upload` ที่ตรวจ JWT ก่อน และเก็บความลับ
// ไว้ฝั่งเซิร์ฟเวอร์อย่างเดียว
//
// public API ของไฟล์นี้ไม่เปลี่ยน — 11 ไฟล์ที่เรียกใช้อยู่จึงไม่ต้องแก้อะไรเลย
const FN_URL   = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/media-upload`
const ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY || ''
// ยังอ่าน URL ของ host ไว้ใช้ตัดสินว่า url ที่จะลบเป็นของ host นี้หรือของ Supabase storage
const API_URL  = import.meta.env.VITE_UPLOAD_API_URL || ''
const API_BASE = API_URL.replace(/upload\.php$/, '')

/** token ของผู้ใช้ที่ล็อกอินอยู่ — ไม่มี session = อัปโหลดผ่าน host ไม่ได้ */
async function authHeaders() {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session?.access_token) throw new Error('ต้องเข้าสู่ระบบก่อนจึงจะอัปโหลดไฟล์ได้')
  return { Authorization: `Bearer ${session.access_token}`, apikey: ANON_KEY }
}

export const externalUploadEnabled = !!API_URL

// ลบไฟล์ที่เคยอัปโหลด — รองรับทั้ง URL จาก host ภายนอกและ Supabase storage
// ใช้ตอนลบ/แทนที่ banner หรือข่าว เพื่อไม่ให้ไฟล์ค้างสะสม
export async function deleteUploadedFile(url) {
  if (!url) return
  try {
    if (externalUploadEnabled && API_BASE && url.startsWith(API_BASE)) {
      await fetch(FN_URL, {
        method: 'POST',
        headers: { ...(await authHeaders()), 'Content-Type': 'application/json' },
        body: JSON.stringify({ action: 'delete', url }),
      })
      return
    }
    const m = url.match(/\/storage\/v1\/object\/public\/([^/]+)\/(.+)$/)
    if (m) {
      const [, bucket, path] = m
      await supabase.storage.from(bucket).remove([decodeURIComponent(path)])
    }
  } catch {
    // เงียบไว้ — ลบ record ใน DB สำเร็จเป็นหลัก ไฟล์ orphan ลบทีหลังได้
  }
}

export function useExternalUpload() {
  const uploading = ref(false)
  const error = ref('')

  async function uploadImage(blob, category = 'misc') {
    uploading.value = true
    error.value = ''
    try {
      const fd = new FormData()
      fd.append('file', blob, `${category}.png`)
      fd.append('category', category)
      const res = await fetch(FN_URL, {
        method: 'POST',
        headers: await authHeaders(),
        body: fd,
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || 'อัปโหลดไม่สำเร็จ')
      return data.url
    } catch (e) {
      error.value = e.message || 'อัปโหลดไม่สำเร็จ'
      throw e
    } finally {
      uploading.value = false
    }
  }

  // อัปโหลดไฟล์ทั่วไป (เช่นวิดีโอ) ผ่าน XHR เพื่อให้ติดตาม progress ได้
  async function uploadFile(file, category = 'misc', onProgress) {
    uploading.value = true
    error.value = ''
    // ขอ token ก่อนเปิด XHR — ยังใช้ XHR อยู่เพราะต้องการแถบความคืบหน้า
    let headers
    try {
      headers = await authHeaders()
    } catch (e) {
      uploading.value = false
      error.value = e.message
      throw e
    }
    return new Promise((resolve, reject) => {
      const fd = new FormData()
      fd.append('file', file, file.name)
      fd.append('category', category)

      const xhr = new XMLHttpRequest()
      xhr.open('POST', FN_URL)
      Object.entries(headers).forEach(([k, v]) => xhr.setRequestHeader(k, v))

      xhr.upload.addEventListener('progress', ev => {
        if (ev.lengthComputable) onProgress?.(Math.round((ev.loaded / ev.total) * 100))
      })
      xhr.addEventListener('load', () => {
        uploading.value = false
        let data
        try { data = JSON.parse(xhr.responseText) } catch { data = {} }
        if (xhr.status >= 200 && xhr.status < 300 && data.url) {
          resolve(data.url)
        } else {
          error.value = data.error || `อัปโหลดไม่สำเร็จ (${xhr.status})`
          reject(new Error(error.value))
        }
      })
      xhr.addEventListener('error', () => {
        uploading.value = false
        error.value = 'Network error'
        reject(new Error(error.value))
      })
      xhr.send(fd)
    })
  }

  return { uploading, error, uploadImage, uploadFile }
}
