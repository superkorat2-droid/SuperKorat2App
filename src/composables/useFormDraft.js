// กันข้อมูลหายเมื่อเน็ตหลุด/ปิดแท็บกลางคัน — เก็บ draft ไว้ใน localStorage
// ใช้ร่วมกันระหว่างหน้ากรอกแบบนิเทศสาธารณะ (token) และ school portal
import { watch } from 'vue'

export function useFormDraft(storageKey, getState, applyState) {
  function restoreDraft() {
    try {
      const raw = localStorage.getItem(storageKey)
      if (!raw) return false
      applyState(JSON.parse(raw))
      return true
    } catch {
      return false
    }
  }

  function clearDraft() {
    try { localStorage.removeItem(storageKey) } catch { /* noop */ }
  }

  let saveTimer = null
  function watchAndSave() {
    watch(getState, (state) => {
      clearTimeout(saveTimer)
      saveTimer = setTimeout(() => {
        try { localStorage.setItem(storageKey, JSON.stringify(state)) } catch { /* noop, e.g. storage full */ }
      }, 400)
    }, { deep: true })
  }

  return { restoreDraft, clearDraft, watchAndSave }
}
