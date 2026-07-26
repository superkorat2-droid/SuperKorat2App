<script setup>
/**
 * EmbedPersonnelView — /embed/personnel
 *
 * หน้าเนื้อหาล้วนสำหรับฝังใน iframe ของเว็บภายนอก (เว็บหลักของเขตเป็น WordPress)
 * ใช้ PersonnelDirectory ตัวเดียวกับหน้า /personnel → หน้าตาเหมือนกันเป๊ะและอัปเดตตามกันเสมอ
 *
 * ทำไมต้อง iframe ไม่ inject HTML เข้าไปตรงๆ: ธีม WordPress มี CSS ครอบกว้าง
 * (เช่น .entry-content img { width:100% }) ถ้า inject markup จะโดนธีมทับจนเพี้ยน
 * และเพี้ยนไม่เหมือนกันในแต่ละธีม — iframe แยก style ขาดจากกัน
 *
 * App.vue ซ่อน navbar/footer ให้ทุก route ที่ขึ้นต้นด้วย /embed/
 *
 * พารามิเตอร์ (ส่งมาทาง query string จาก personnel.js):
 *   contact=off  ปิดโมดัลรายละเอียด/ช่องทางติดต่อ เหลือแค่รายชื่อ
 *
 * พื้นหลังใช้ของเว็บนิเทศ (aurora อ่อน ๆ จาก style.css ระดับ global) ตั้งใจไม่ทำ
 * ตัวเลือกโปร่งใส เพราะการ์ดกระจกออกแบบมาบนพื้นนี้ ถอดออกแล้วขอบการ์ดจะจาง
 */
import { ref, computed, onMounted, onBeforeUnmount } from 'vue'
import { useRoute } from 'vue-router'
import { useAreaConfig } from '../composables/useAreaConfig'
import { fetchPersonnel } from '../composables/usePersonnel'
import PersonnelDirectory from '../components/personnel/PersonnelDirectory.vue'

const route = useRoute()
const { config, fetchConfig } = useAreaConfig()

const loading   = ref(true)
const loadError = ref('')
const personnel = ref([])
const rootEl    = ref(null)

// target="_blank" ต้องเป็น URL เต็ม เพราะลิงก์สัมพัทธ์ใน iframe จะอ้างจากโดเมนของเว็บที่ฝัง
const fullSiteUrl = `${window.location.origin}${window.location.pathname}#/personnel`

const showContact = computed(() => route.query.contact !== 'off')
const groupConfig = computed(() => config.value?.personnel_groups || [])

// ── แจ้งความสูงให้หน้าที่ฝังปรับ iframe (ไม่งั้นจะมี scrollbar ซ้อน) ──
let ro = null
let lastH = 0
function postHeight() {
  if (!window.parent || window.parent === window) return
  // ต้องวัดความสูง "เนื้อหา" จาก element ไม่ใช่ documentElement.scrollHeight
  // เพราะ scrollHeight ถูกดันให้เท่า viewport ของ iframe เสมอเมื่อเนื้อหาสั้นกว่า
  // → iframe จะยืดได้แต่หดไม่ได้ ค้างที่ความสูงเริ่มต้นตลอด
  const el = rootEl.value
  const h = Math.ceil(el ? el.getBoundingClientRect().height : document.body.scrollHeight)
  if (h <= 0 || h === lastH) return
  lastH = h
  window.parent.postMessage({ type: 'superkorat-embed-height', name: 'personnel', height: h }, '*')
}

onMounted(async () => {
  await fetchConfig()
  const { rows, error } = await fetchPersonnel()
  if (error) loadError.value = error.message || 'โหลดข้อมูลไม่สำเร็จ'
  personnel.value = rows
  loading.value = false

  // ResizeObserver จับการโหลดรูป/การจัดเรียงใหม่ — เชื่อถือได้กว่า setTimeout เดาเวลา
  // สังเกต rootEl (เนื้อหา) ไม่ใช่ documentElement ตามเหตุผลใน postHeight()
  if ('ResizeObserver' in window && rootEl.value) {
    ro = new ResizeObserver(postHeight)
    ro.observe(rootEl.value)
  }
  window.addEventListener('load', postHeight)
  postHeight()
})

onBeforeUnmount(() => {
  ro?.disconnect()
  window.removeEventListener('load', postHeight)
})
</script>

<template>
  <div ref="rootEl" class="font-sarabun">
    <div class="max-w-6xl mx-auto px-3 py-4">

      <div v-if="loading" class="flex justify-center py-16">
        <div class="w-9 h-9 border-4 border-primary/30 border-t-primary rounded-full animate-spin"/>
      </div>

      <div v-else-if="loadError" class="text-center py-12 text-sm text-slate-500">
        <p class="text-3xl mb-2">⚠️</p>
        <p class="font-bold text-slate-600">โหลดข้อมูลบุคลากรไม่สำเร็จ</p>
        <p class="text-xs mt-1">{{ loadError }}</p>
      </div>

      <div v-else-if="!personnel.length" class="text-center py-12 text-sm text-slate-500">
        ยังไม่มีข้อมูลบุคลากร
      </div>

      <PersonnelDirectory v-else
        :personnel="personnel" :group-config="groupConfig" :show-contact="showContact"/>

      <!-- เครดิตแหล่งข้อมูล — ให้คนดูรู้ว่าข้อมูลมาจากไหนและกดไปดูฉบับเต็มได้ -->
      <p v-if="!loading && personnel.length" class="text-center text-[11px] text-slate-400 pt-1 pb-2">
        ข้อมูลจาก
        <a :href="fullSiteUrl" target="_blank" rel="noopener"
          class="font-bold hover:underline" style="color:var(--color-primary)">
          ทำเนียบบุคลากร {{ config?.area_name || '' }}
        </a>
        · อัปเดตอัตโนมัติ
      </p>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
