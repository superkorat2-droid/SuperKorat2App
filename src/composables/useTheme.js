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

// init จาก localStorage ตอนโหลด module
isDark.value = localStorage.getItem('theme') === 'dark'
applyTheme(isDark.value)

export function useTheme() {
  function toggle() {
    isDark.value = !isDark.value
    applyTheme(isDark.value)
  }
  return { isDark, toggle }
}
