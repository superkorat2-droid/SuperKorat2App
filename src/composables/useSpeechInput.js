/**
 * useSpeechInput — พิมพ์ด้วยเสียงภาษาไทย ผ่าน Web Speech API (ฟรี ไม่ต้องมี API key)
 *
 * ใช้เป็น "ของแถม" ไม่ใช่ทางหลัก — Safari บน iPhone ไม่รองรับ API นี้
 * ผู้เรียกต้องซ่อนปุ่มเองเมื่อ speechSupported เป็น false แล้วบอกผู้ใช้ให้กดไมค์
 * บนแป้นพิมพ์แทน (Gboard/คีย์บอร์ด iOS ถอดเสียงไทยได้ดีอยู่แล้วและใช้ได้ทุกเครื่อง)
 *
 * ⚠️ กับดักบนมือถือ: recognition หยุดเองเมื่อเงียบ 2-3 วินาที ทั้งที่ผู้ใช้ยังพูดไม่จบ
 * จึงต้อง start ใหม่ใน onend ตราบใดที่ยังไม่ได้กดหยุด และต้อง abort() ตอน unmount
 * ไม่งั้นไมค์ค้างเปิดหลังออกจากหน้า
 */
import { ref, onBeforeUnmount } from 'vue'

const SR = typeof window !== 'undefined'
  ? (window.SpeechRecognition || window.webkitSpeechRecognition)
  : null

export const speechSupported = !!SR

export function useSpeechInput() {
  const listening = ref(false)
  const error = ref('')
  const interim = ref('')

  let rec = null
  let wantStop = false
  let onTextCb = null
  let baseText = ''

  function stop() {
    wantStop = true
    listening.value = false
    interim.value = ''
    try { rec?.stop() } catch { /* ปิดอยู่แล้ว */ }
  }

  /**
   * @param {string} current ข้อความเดิมในช่อง — ผลลัพธ์จะ "ต่อท้าย" ไม่ทับของเดิม
   * @param {(text:string)=>void} onText เรียกทุกครั้งที่มีข้อความใหม่
   */
  function start(current, onText) {
    if (!SR) { error.value = 'เบราว์เซอร์นี้ไม่รองรับการพิมพ์ด้วยเสียง'; return }
    if (listening.value) { stop(); return }

    error.value = ''
    wantStop = false
    onTextCb = onText
    baseText = current || ''

    rec = new SR()
    rec.lang = 'th-TH'
    rec.continuous = true
    rec.interimResults = true

    rec.onresult = (e) => {
      let finalAdd = '', pending = ''
      for (let i = e.resultIndex; i < e.results.length; i++) {
        const t = e.results[i][0].transcript
        if (e.results[i].isFinal) finalAdd += t
        else pending += t
      }
      if (finalAdd) {
        baseText = baseText ? `${baseText} ${finalAdd}`.replace(/\s+/g, ' ') : finalAdd
        onTextCb?.(baseText)
      }
      interim.value = pending
    }

    rec.onerror = (e) => {
      // no-speech เกิดบ่อยมากและไม่ใช่ความผิดพลาดจริง ปล่อยให้ onend เริ่มใหม่เอง
      if (e.error === 'no-speech' || e.error === 'aborted') return
      error.value = e.error === 'not-allowed'
        ? 'ไม่ได้รับอนุญาตให้ใช้ไมโครโฟน — กรุณาอนุญาตในการตั้งค่าเบราว์เซอร์'
        : 'ฟังเสียงไม่สำเร็จ: ' + e.error
      stop()
    }

    // บนมือถือจะหยุดเองเมื่อเงียบ — เริ่มใหม่ให้ตราบใดที่ผู้ใช้ยังไม่กดหยุด
    rec.onend = () => {
      if (wantStop) { listening.value = false; return }
      try { rec.start() } catch { listening.value = false }
    }

    try {
      rec.start()
      listening.value = true
    } catch (e) {
      error.value = 'เริ่มฟังเสียงไม่สำเร็จ'
      listening.value = false
    }
  }

  // ต้องปิดไมค์เสมอ ไม่งั้นค้างเปิดหลังออกจากหน้า
  onBeforeUnmount(() => {
    wantStop = true
    try { rec?.abort() } catch { /* ไม่มีอะไรให้ปิด */ }
  })

  return { listening, error, interim, start, stop }
}
