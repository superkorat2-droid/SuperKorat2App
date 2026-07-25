import { ref } from 'vue'
import { deleteUploadedFile } from './useExternalUpload'

/**
 * useUploadGc — เก็บกวาดไฟล์รูปบน server ไม่ให้ค้างสะสมกินพื้นที่
 *
 * ปัญหาที่แก้: ถ้าลบไฟล์เก่า "ทันทีที่อัปโหลดรูปใหม่" แล้วผู้ใช้กดยกเลิก/ปิดหน้า
 * โดยไม่บันทึก จะได้ DB ที่ชี้ไปยังไฟล์ที่ถูกลบไปแล้ว (รูปหายจากเว็บจริง)
 * เดิมโปรเจคนี้จึงเลือก "ไม่ลบเลย" แล้วยอมให้มีไฟล์ orphan
 *
 * วิธีที่ใช้แทน — ผูกการลบไว้กับผลของการบันทึก:
 *   • อัปโหลดรูปใหม่      → trackUploaded(urlใหม่) + trackReplaced(urlเก่า)
 *   • บันทึกสำเร็จ        → commit(urlsที่ยังใช้อยู่) → ลบ "รูปเก่า" ทิ้ง
 *   • ออกจากหน้าโดยไม่บันทึก → discard() → ลบ "รูปใหม่" ที่อัปไปแล้วแต่ไม่ได้ใช้
 *
 * ผลคือไม่ว่าจะจบทางไหน ไฟล์ที่เหลือบน server ก็ตรงกับที่ DB ชี้เสมอ
 */
export function useUploadGc() {
  const uploaded = ref(new Set())   // อัปในเซสชันนี้ — ลบถ้าไม่ได้บันทึก
  const replaced = ref(new Set())   // ของเดิมที่ถูกแทนที่/ลบ — ลบเมื่อบันทึกสำเร็จ

  function trackUploaded(url) {
    if (url) uploaded.value.add(url)
  }

  function trackReplaced(url) {
    if (!url) return
    // ถ้าเป็นรูปที่เพิ่งอัปในเซสชันนี้แล้วเปลี่ยนใจอีกที ลบได้เลยทันที
    // ไม่ต้องรอบันทึก เพราะ DB ไม่เคยรู้จักมันมาก่อน
    if (uploaded.value.has(url)) {
      uploaded.value.delete(url)
      deleteUploadedFile(url)
      return
    }
    replaced.value.add(url)
  }

  /**
   * เรียกหลังบันทึกสำเร็จเท่านั้น
   * @param {string[]} stillUsed - URL ทั้งหมดที่ payload ที่เพิ่งบันทึกยังอ้างถึง
   *        (กันเคสรูปเดียวถูกใช้หลาย section แล้วลบอันหนึ่งไปทำให้อีกอันรูปหาย)
   */
  async function commit(stillUsed = []) {
    const keep = new Set(stillUsed.filter(Boolean))
    const targets = [...replaced.value].filter(u => !keep.has(u))
    replaced.value.clear()
    uploaded.value.clear()
    await Promise.all(targets.map(u => deleteUploadedFile(u)))
    return targets.length
  }

  /** เรียกเมื่อออกจากหน้าโดยไม่บันทึก — ลบรูปที่อัปไปแล้วแต่ไม่มีใครใช้ */
  async function discard() {
    const targets = [...uploaded.value]
    uploaded.value.clear()
    replaced.value.clear()
    await Promise.all(targets.map(u => deleteUploadedFile(u)))
    return targets.length
  }

  return { trackUploaded, trackReplaced, commit, discard, uploaded, replaced }
}
