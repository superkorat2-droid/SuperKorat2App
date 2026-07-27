/**
 * useBlockCollapse — พับบล็อก/เซกชันให้เหลือแค่หัวแถบ
 *
 * ปัญหาที่แก้: หน้าจัดการเนื้อหา (CMS) กับหน้าเซกชันหน้าแรก พอมีบล็อกเยอะ ๆ
 * ฟอร์มแต่ละอันสูงเป็นจอ ต้องเลื่อนหาไปมาจนงง สลับ/เพิ่ม/แก้ลำบาก
 *
 * เก็บสถานะพับไว้ในหน่วยความจำเท่านั้น (ไม่ลงฐานข้อมูล) เพราะเป็นเรื่องของ
 * "มุมมองขณะแก้ไข" ไม่ใช่เนื้อหา — ถ้าเก็บลง blocks จะไปเพิ่ม key แปลกปลอม
 * ให้ตัว renderer ฝั่งหน้าเว็บจริงด้วย
 *
 * Vue 3 ติดตาม Set/Map ได้จริง (collection handlers) จึง add/delete ตรง ๆ ได้
 */
import { ref } from 'vue'

/**
 * @param {object} opts
 * @param {number} opts.autoAt  มีของตั้งแต่กี่ชิ้นขึ้นไปถึงจะพับให้อัตโนมัติตอนเปิดหน้า
 */
export function useBlockCollapse({ autoAt = 3 } = {}) {
  const collapsed = ref(new Set())

  const isCollapsed = id => collapsed.value.has(id)

  function toggle(id) {
    if (collapsed.value.has(id)) collapsed.value.delete(id)
    else collapsed.value.add(id)
  }

  function expand(id)   { collapsed.value.delete(id) }
  function expandAll()  { collapsed.value.clear() }

  function collapseAll(ids) {
    collapsed.value.clear()
    ids.forEach(id => collapsed.value.add(id))
  }

  /** เรียกหลังโหลดข้อมูลเดิม — หน้าที่มีของเยอะเปิดมาแล้วเห็นภาพรวมทั้งหมดก่อน */
  function autoCollapse(ids) {
    if (ids.length >= autoAt) collapseAll(ids)
  }

  return { collapsed, isCollapsed, toggle, expand, expandAll, collapseAll, autoCollapse }
}

/** ตัดข้อความยาว ๆ ให้พอดีหัวแถบ และล้างแท็ก HTML ออกก่อน */
function short(v, len = 60) {
  const s = String(v ?? '').replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim()
  if (!s) return ''
  return s.length > len ? s.slice(0, len) + '…' : s
}

/**
 * ข้อความสรุปย่อของบล็อก ใช้โชว์ตอนพับเพื่อให้รู้ว่าอันไหนเป็นอันไหน
 * โดยไม่ต้องกางออกดู — ครอบคลุมทุกชนิดบล็อกทั้งของหน้า CMS และของสื่อ/ผลงาน
 */
export function blockPreview(b) {
  if (!b) return ''
  switch (b.type) {
    case 'heading':    return short(b.text)
    case 'text':       return short(b.text)
    case 'html':       return short(b.code, 50)
    case 'divider':    return '— เส้นคั่น —'
    case 'image':      return short(b.caption) || short(b.alt) || short(b.url, 50)
    case 'embed':      return short(b.label, 40) || short(b.url, 50)
    case 'media-text': return short(b.heading) || short(b.text) || short(b.url, 40)
    case 'button':     return short(b.text) || short(b.link_url, 40)
    case 'gallery':    return [short(b.title, 40), countLabel(b.items, 'รูป')].filter(Boolean).join(' · ')
    case 'accordion':  return [countLabel(b.items, 'หัวข้อ'), short(b.items?.[0]?.question, 34)].filter(Boolean).join(' · ')
    case 'youtube':    return [short(b.title, 40), countLabel(b.items, 'คลิป')].filter(Boolean).join(' · ')
    // บล็อก drive มี 2 แบบ: ของหน้า CMS ใช้ title/folder_id · ของสื่อ/ผลงานใช้ label/url
    case 'drive':      return short(b.title, 40) || short(b.label, 40)
                           || (b.folder_id ? 'โฟลเดอร์ ' + short(b.folder_id, 24) : short(b.url, 44))
                           || 'ยังไม่ได้ใส่ลิงก์'
    default:           return short(b.title) || short(b.text)
  }
}

function countLabel(arr, unit) {
  const n = Array.isArray(arr) ? arr.length : 0
  return n ? `${n} ${unit}` : ''
}
