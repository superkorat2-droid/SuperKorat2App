import { ref } from 'vue'

/**
 * useGoogleDrive — ตัวช่วย Google Drive ใช้ร่วมกันทั้งโปรเจค
 *
 * เดิม extractFileId() ถูก copy-paste อยู่ 5 ไฟล์ (จดหมายข่าว/สื่อ ทั้งฝั่ง admin
 * และโรงเรียน) และยังไม่รองรับลิงก์โฟลเดอร์ — รวบมาไว้ที่นี่ที่เดียว
 */

// ── แยก id จากลิงก์ Drive ───────────────────────────────────────────
const PATTERNS = [
  { re: /\/folders\/([a-zA-Z0-9_-]+)/,        kind: 'folder' },  // .../drive/folders/<id>
  { re: /\/file\/d\/([a-zA-Z0-9_-]+)/,        kind: 'file'   },  // .../file/d/<id>/view
  { re: /\/d\/([a-zA-Z0-9_-]+)/,              kind: 'file'   },  // docs/sheets/slides /d/<id>/edit
  { re: /[?&]id=([a-zA-Z0-9_-]+)/,            kind: 'file'   },  // ...open?id=<id>
]

/** @returns {{ id: string, kind: 'folder'|'file'|'' }} */
export function parseDriveUrl(url) {
  if (!url) return { id: '', kind: '' }
  const s = String(url).trim()
  for (const p of PATTERNS) {
    const m = s.match(p.re)
    if (m) return { id: m[1], kind: p.kind }
  }
  // วาง id เปล่ามา — เดาไม่ได้ว่าไฟล์หรือโฟลเดอร์ ให้ caller ตัดสินเอง
  if (/^[a-zA-Z0-9_-]{10,120}$/.test(s)) return { id: s, kind: '' }
  return { id: '', kind: '' }
}

/** ใช้แทน extractFileId เดิม — คืนเฉพาะ id (string ว่างถ้าไม่เจอ) */
export function extractDriveId(url) {
  return parseDriveUrl(url).id
}

export function drivePreviewUrl(id) { return id ? `https://drive.google.com/file/d/${id}/preview` : '' }
export function driveViewUrl(id)    { return id ? `https://drive.google.com/file/d/${id}/view` : '' }
export function driveFolderUrl(id)  { return id ? `https://drive.google.com/drive/folders/${id}` : '' }

/**
 * ภาพปกของไฟล์ Drive — ใช้แทนการฝัง iframe เวลาต้องแสดงหลายใบพร้อมกัน
 *
 * วัดจริงด้วย 12 ใบ: iframe = 439 คำขอ / 37.95 MB · <img> = 7 คำขอ / 0.59 MB
 * (ต่างกัน 64 เท่า) จึงห้ามใช้ iframe ทำ "ภาพปก" อีก — iframe เก็บไว้ใช้เฉพาะ
 * ตอนเปิดอ่านเอกสารจริงทีละอันเท่านั้น
 *
 * ⚠️ URL ของ Google เปลี่ยนได้โดยไม่บอกล่วงหน้า **ให้ทุกที่เรียกฟังก์ชันนี้เท่านั้น**
 * จะได้แก้จุดเดียวจบ และผู้เรียกต้องมี fallback ตอนโหลดภาพไม่สำเร็จเสมอ
 * (ดู NewsletterThumb.vue) — ทดสอบแล้ว 2569-08-01 ใช้ได้ 12/12 แคชว่าง
 * ตอบ 302 ไป lh3.googleusercontent.com แล้ว 200 image/jpeg|png
 *
 * หมายเหตุ: `uc?export=view&id=` เป็นตัวที่ Google เลิกใช้จริง (ทดสอบแล้วตาย 4/4)
 * อย่าสับสนกับตัวนี้
 */
export function driveThumb(id, size = 600) {
  return id ? `https://drive.google.com/thumbnail?id=${id}&sz=w${size}` : ''
}

// ── ชนิดไฟล์ ────────────────────────────────────────────────────────
export const FOLDER_MIME = 'application/vnd.google-apps.folder'

// ใช้ทั้งไอคอนบนการ์ดและตัวเลือกในฟิลเตอร์ — นิยามที่เดียวไม่ให้หลุดกัน
export const FILE_KINDS = [
  { key: 'folder', label: 'โฟลเดอร์', color: 'text-amber-600',   bg: 'bg-amber-100',   test: m => m === FOLDER_MIME },
  { key: 'pdf',    label: 'PDF',      color: 'text-rose-600',    bg: 'bg-rose-100',    test: m => m === 'application/pdf' },
  { key: 'doc',    label: 'เอกสาร',   color: 'text-blue-600',    bg: 'bg-blue-100',    test: m => /document|msword|wordprocessing|text\//.test(m) },
  { key: 'sheet',  label: 'ตาราง',    color: 'text-emerald-600', bg: 'bg-emerald-100', test: m => /spreadsheet|excel|csv/.test(m) },
  { key: 'slide',  label: 'สไลด์',    color: 'text-orange-600',  bg: 'bg-orange-100',  test: m => /presentation|powerpoint/.test(m) },
  { key: 'image',  label: 'รูปภาพ',   color: 'text-violet-600',  bg: 'bg-violet-100',  test: m => m.startsWith('image/') },
  { key: 'video',  label: 'วิดีโอ',   color: 'text-red-600',     bg: 'bg-red-100',     test: m => m.startsWith('video/') },
  { key: 'audio',  label: 'เสียง',    color: 'text-cyan-600',    bg: 'bg-cyan-100',    test: m => m.startsWith('audio/') },
  { key: 'zip',    label: 'บีบอัด',   color: 'text-slate-600',   bg: 'bg-slate-200',   test: m => /zip|rar|7z|tar|compressed/.test(m) },
  { key: 'other',  label: 'อื่นๆ',    color: 'text-slate-500',   bg: 'bg-slate-100',   test: () => true },
]

export function fileKind(mimeType) {
  const m = mimeType || ''
  return FILE_KINDS.find(k => k.test(m)) || FILE_KINDS[FILE_KINDS.length - 1]
}

export function isFolder(file) { return file?.mimeType === FOLDER_MIME }

export const SHORTCUT_MIME = 'application/vnd.google-apps.shortcut'

/**
 * แปลง "ทางลัด" (shortcut) ให้กลายเป็นเป้าหมายจริง
 *
 * ถ้าผู้ใช้เอาโฟลเดอร์/ไฟล์จากที่อื่นมา "เพิ่มทางลัด" ไว้ในโฟลเดอร์ที่แชร์
 * Google จะคืน mimeType เป็น shortcut พร้อม shortcutDetails.targetId/targetMimeType
 * ถ้าไม่แปล ฝั่งหน้าเว็บจะเห็นเป็นไฟล์ชนิดไม่รู้จัก → คลิกโฟลเดอร์แล้วไม่เข้า
 * และตัวอย่างไฟล์ก็เปิดไม่ขึ้น (อาการที่ user เจอในหน้า CMS)
 *
 * คง id เดิมไว้ที่ shortcutId เผื่อต้องอ้างอิงตัวทางลัดจริงๆ
 */
export function resolveShortcut(f) {
  if (!f || f.mimeType !== SHORTCUT_MIME) return f
  const t = f.shortcutDetails
  if (!t?.targetId) return f
  return {
    ...f,
    id: t.targetId,
    mimeType: t.targetMimeType || f.mimeType,
    isShortcut: true,
    shortcutId: f.id,
  }
}

export function formatSize(bytes) {
  const n = Number(bytes)
  if (!n) return ''            // โฟลเดอร์และไฟล์ Google Docs ไม่มี size
  const u = ['B', 'KB', 'MB', 'GB']
  let i = 0, v = n
  while (v >= 1024 && i < u.length - 1) { v /= 1024; i++ }
  return `${v.toFixed(v >= 10 || i === 0 ? 0 : 1)} ${u[i]}`
}

export function formatDate(iso) {
  if (!iso) return ''
  return new Date(iso).toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: '2-digit' })
}

// ── โหลดรายการในโฟลเดอร์ ────────────────────────────────────────────
// cache ระดับ module ตาม pattern useEducationNews.js — กันยิงซ้ำตอนสลับหน้า
// และประหยัดโควตา Drive API (edge function ก็ cache อีกชั้น 10 นาที)
const CACHE_TTL = 10 * 60 * 1000
const _cache = new Map()   // folderId → { ts, files }

function fnBase() {
  const base = import.meta.env.VITE_SUPABASE_URL || ''
  return `${base.replace(/\/$/, '')}/functions/v1/drive-list`
}

export function useDriveFolder() {
  const files   = ref([])
  const loading = ref(false)
  const error   = ref('')

  async function fetchFolder(folderId, { force = false } = {}) {
    if (!folderId) { files.value = []; return [] }

    const hit = _cache.get(folderId)
    if (!force && hit && Date.now() - hit.ts < CACHE_TTL) {
      files.value = hit.files
      error.value = ''
      return hit.files
    }

    loading.value = true
    error.value = ''
    try {
      const res = await fetch(`${fnBase()}?folderId=${encodeURIComponent(folderId)}`, {
        headers: { apikey: import.meta.env.VITE_SUPABASE_ANON_KEY || '' },
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data?.message || 'โหลดรายการไฟล์ไม่สำเร็จ')

      const list = (Array.isArray(data.files) ? data.files : []).map(resolveShortcut)
      _cache.set(folderId, { ts: Date.now(), files: list })
      files.value = list
      return list
    } catch (e) {
      error.value = e.message || 'โหลดรายการไฟล์ไม่สำเร็จ'
      files.value = []
      return []
    } finally {
      loading.value = false
    }
  }

  return { files, loading, error, fetchFolder }
}
