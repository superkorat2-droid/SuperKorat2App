/**
 * useEmbed — ตัวช่วยสำหรับ "ฝังลิงก์" (YouTube / Drive / Slides / Canva / PDF / iframe อื่น)
 *
 * ที่มา: ตรรกะชุดนี้เคยถูกก๊อปไว้ 4 ที่ (AdminNewsView, AdminPageEditorView,
 * NewsDetailView, DynamicPageView) และ **แต่ละที่ทำไม่เหมือนกัน** เช่นของข่าว
 * รองรับ PDF ผ่าน Google Docs Viewer แต่ของหน้า CMS ไม่รองรับ
 * ไฟล์นี้รวมเวอร์ชันที่ครอบคลุมที่สุดไว้ที่เดียว สำหรับของใหม่ให้ใช้ตัวนี้
 *
 * ยังไม่ไปแทนที่ 4 ที่เดิม เพราะพฤติกรรมต่างกันจริง เปลี่ยนพร้อมกันเสี่ยงทำหน้าเดิมเพี้ยน
 * ถ้าจะรวมควรทำเป็นงานแยกที่มีการทดสอบหน้าเหล่านั้นครบ
 */

export const EMBED_TYPES = {
  youtube: { label: 'YouTube',       color: 'bg-red-100 text-red-700' },
  drive:   { label: 'Google Drive',  color: 'bg-blue-100 text-blue-700' },
  slides:  { label: 'Google Slides', color: 'bg-yellow-100 text-yellow-700' },
  docs:    { label: 'Google Docs',   color: 'bg-sky-100 text-sky-700' },
  sheets:  { label: 'Google Sheets', color: 'bg-emerald-100 text-emerald-700' },
  forms:   { label: 'Google Forms',  color: 'bg-violet-100 text-violet-700' },
  maps:    { label: 'Google Maps',   color: 'bg-teal-100 text-teal-700' },
  canva:   { label: 'Canva',         color: 'bg-purple-100 text-purple-700' },
  facebook:{ label: 'Facebook',      color: 'bg-indigo-100 text-indigo-700' },
  pdf:     { label: 'PDF',           color: 'bg-orange-100 text-orange-700' },
  iframe:  { label: 'เว็บอื่น ๆ',    color: 'bg-slate-100 text-slate-600' },
}

export const ASPECT_OPTIONS = [
  { value: '16/9', label: '16:9 (วิดีโอ)' },
  { value: '4/3',  label: '4:3'          },
  { value: '1/1',  label: '1:1 (จัตุรัส)' },
  { value: '3/4',  label: '3:4 (แนวตั้ง)' },
  { value: '21/9', label: '21:9 (กว้างพิเศษ)' },
]

/** เดาชนิดจาก URL — คืน '' เมื่อยังไม่ได้กรอก เพื่อให้ UI แยกได้ว่า "ว่าง" กับ "ไม่รู้จัก" */
export function detectEmbedType(url) {
  if (!url) return ''
  if (/youtube\.com\/watch|youtu\.be\/|youtube\.com\/embed/.test(url)) return 'youtube'
  if (/docs\.google\.com\/presentation/.test(url)) return 'slides'
  if (/docs\.google\.com\/document/.test(url))     return 'docs'
  if (/docs\.google\.com\/spreadsheets/.test(url)) return 'sheets'
  if (/docs\.google\.com\/forms|forms\.gle/.test(url)) return 'forms'
  if (/google\.com\/maps|maps\.app\.goo\.gl/.test(url)) return 'maps'
  if (/drive\.google\.com/.test(url))              return 'drive'
  if (/canva\.com/.test(url))                      return 'canva'
  if (/facebook\.com|fb\.watch/.test(url))         return 'facebook'
  if (/\.pdf(\?|#|$)/i.test(url))                  return 'pdf'
  if (/^https?:\/\//.test(url))                    return 'iframe'
  return ''
}

/** แปลง URL ที่คนทั่วไปก๊อปมา ให้เป็น URL ที่ฝัง iframe ได้จริง */
export function toEmbedUrl(url, type) {
  if (!url) return ''
  const t = type || detectEmbedType(url)

  switch (t) {
    case 'youtube': {
      const m = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&?/]+)/)
      return m ? `https://www.youtube.com/embed/${m[1]}?rel=0` : url
    }
    case 'drive':
      return url.replace(/\/view.*$/, '/preview')
    case 'slides':
      return url.replace(/\/(edit|view|preview|pub).*$/, '/embed?start=false&loop=false&delayms=3000')
    case 'docs':
    case 'sheets':
      return url.replace(/\/(edit|view).*$/, '/preview')
    case 'forms':
      return url.includes('/viewform') ? url.replace(/\?.*$/, '?embedded=true') : url
    case 'canva':
      return url.replace(/\/(edit|view|watch).*$/, '/view?embed')
    case 'pdf':
      // PDF จากเว็บอื่นฝังตรง ๆ มักโดนบล็อก ให้ผ่าน Google Docs Viewer
      if (url.includes('docs.google.com/viewer')) return url
      return `https://docs.google.com/viewer?url=${encodeURIComponent(url)}&embedded=true`
    case 'facebook':
      return `https://www.facebook.com/plugins/video.php?href=${encodeURIComponent(url)}&show_text=false`
    default:
      return url
  }
}

/** ภาพปกของคลิป YouTube — ใช้โชว์ตัวอย่างเร็ว ๆ โดยไม่ต้องโหลด iframe */
export function youtubeThumb(url) {
  const m = String(url || '').match(/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&?/]+)/)
  return m ? `https://img.youtube.com/vi/${m[1]}/mqdefault.jpg` : ''
}
