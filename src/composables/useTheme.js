import { ref } from 'vue'

const isDark = ref(false)

function applyTheme(dark) {
  if (dark) {
    document.documentElement.classList.add('dark')
    localStorage.setItem('theme', 'dark')
  } else {
    document.documentElement.classList.remove('dark')
    localStorage.setItem('theme', 'light')
  }
}

// ปิดใช้งาน dark mode ชั่วคราวระหว่างพัฒนา — หลายหน้ายังมีปัญหาสีข้อความมองไม่เห็นในโหมดมืด
// (ปุ่มสลับถูกซ่อนแล้วใน App.vue; บังคับ light เสมอและล้างค่าเก่าที่อาจค้างจาก localStorage)
isDark.value = false
localStorage.removeItem('theme')
applyTheme(false)

export function useTheme() {
  function toggle() {
    isDark.value = !isDark.value
    applyTheme(isDark.value)
  }
  return { isDark, toggle }
}
