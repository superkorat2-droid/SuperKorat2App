import { createApp } from 'vue'
import { createPinia } from 'pinia'
import VueApexCharts from 'vue3-apexcharts'
import App from './App.vue'
import router from './router'
import SvgIcon from './components/SvgIcon.vue'
import './style.css'

const app = createApp(App)

app.use(createPinia())
app.use(router)
app.use(VueApexCharts)
app.component('SvgIcon', SvgIcon)

// ช่องค้นหาต้องกรองระหว่างพิมพ์บนคีย์บอร์ดมือถือ (ไทย/IME) เหมือนบนคอม
// ปัญหา: v-model ของ Vue ตั้ง composing=true ตอน compositionstart แล้ว "เมิน" input ทุกตัวจนกว่าจะจบคำ
//        (กดเว้นวรรค/เลือกคำแนะนำ) ผลกรองเลยไม่ขึ้นขณะพิมพ์
// วิธีแก้: ดัก compositionstart ที่ capture phase เฉพาะช่องค้นหา ไม่ให้ถึง listener ของ v-model
//          ช่องฟอร์มกรอกข้อมูลทั่วไปไม่ถูกแตะ (จับจาก type=search หรือ placeholder มีคำว่า "ค้นหา")
window.addEventListener('compositionstart', (e) => {
  const el = e.target
  if (el instanceof HTMLInputElement && (el.type === 'search' || /ค้นหา/.test(el.placeholder || ''))) {
    e.stopImmediatePropagation()
  }
}, true)

app.mount('#app')
