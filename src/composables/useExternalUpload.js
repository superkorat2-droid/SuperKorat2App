import { ref } from 'vue'
import { supabase } from '../supabase'

// อัปโหลดรูปไปยัง PHP host ภายนอก (เช่น supervision.korat2.go.th) แทน Supabase Storage
// เปิดใช้งานเมื่อตั้งค่า VITE_UPLOAD_API_URL — ถ้าไม่ตั้งค่า externalUploadEnabled = false
// และ caller ควร fallback ไปใช้ Supabase storage ตามเดิม
const API_URL    = import.meta.env.VITE_UPLOAD_API_URL || ''
const API_SECRET = import.meta.env.VITE_UPLOAD_API_SECRET || ''
const API_BASE   = API_URL.replace(/upload\.php$/, '')
const DELETE_URL = API_BASE + 'delete.php'

export const externalUploadEnabled = !!API_URL

// ลบไฟล์ที่เคยอัปโหลด — รองรับทั้ง URL จาก host ภายนอกและ Supabase storage
// ใช้ตอนลบ/แทนที่ banner หรือข่าว เพื่อไม่ให้ไฟล์ค้างสะสม
export async function deleteUploadedFile(url) {
  if (!url) return
  try {
    if (externalUploadEnabled && url.startsWith(API_BASE)) {
      await fetch(DELETE_URL, {
        method: 'POST',
        headers: { 'X-Upload-Secret': API_SECRET, 'Content-Type': 'application/json' },
        body: JSON.stringify({ url }),
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
      const res = await fetch(API_URL, {
        method: 'POST',
        headers: { 'X-Upload-Secret': API_SECRET },
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
  function uploadFile(file, category = 'misc', onProgress) {
    uploading.value = true
    error.value = ''
    return new Promise((resolve, reject) => {
      const fd = new FormData()
      fd.append('file', file, file.name)
      fd.append('category', category)

      const xhr = new XMLHttpRequest()
      xhr.open('POST', API_URL)
      xhr.setRequestHeader('X-Upload-Secret', API_SECRET)

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
