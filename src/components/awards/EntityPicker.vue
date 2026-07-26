<script setup>
/**
 * EntityPicker — พิมพ์ค้นหา ถ้าเจอในระบบเลือกได้เลย ถ้าไม่เจอก็ใช้ชื่อที่พิมพ์เอง
 *
 * โปรเจคนี้ยังไม่มี type-ahead เลย มีแต่ <select optgroup> กับ checkbox list
 * ซึ่งใช้ไม่ได้กับกรณี "คนนอกเขต/หน่วยงานอื่น" ที่ไม่มีข้อมูลในระบบ
 *
 * ค้นจากตารางไหนขึ้นกับ kind:
 *   school                    → schools (โชว์ศูนย์เครือข่าย/อำเภอ ช่วยแยกชื่อซ้ำ)
 *   teacher/supervisor/staff  → profiles ตามบทบาทนั้น
 *   area/other                → ไม่ค้น พิมพ์อย่างเดียว
 *
 * v-model เป็นอ็อบเจกต์ { label, school_id, profile_id } เพื่อให้ผู้เรียกได้ทั้ง
 * ชื่อที่จะแสดงและตัวอ้างอิงจริง (ถ้ามี) ในคราวเดียว
 */
import { ref, computed, watch, onBeforeUnmount } from 'vue'
import { supabase } from '../../supabase'

const props = defineProps({
  modelValue: { type: Object, default: () => ({ label: '', school_id: null, profile_id: null }) },
  kind:       { type: String, default: 'school' },
  placeholder:{ type: String, default: 'พิมพ์เพื่อค้นหา หรือพิมพ์ชื่อเอง' },
})
const emit = defineEmits(['update:modelValue'])

const text    = ref(props.modelValue.label || '')
const results = ref([])
const open    = ref(false)
const loading = ref(false)

const searchable = computed(() => ['school', 'teacher', 'supervisor', 'staff'].includes(props.kind))
const linked = computed(() => !!(props.modelValue.school_id || props.modelValue.profile_id))

// ผู้เรียกเปลี่ยนค่าจากข้างนอก (เช่นโหลดข้อมูลเดิมมาแก้ไข) ต้องตามให้ทัน
watch(() => props.modelValue.label, v => { if (v !== text.value) text.value = v || '' })

// เปลี่ยนประเภทเจ้าของ = ตัวอ้างอิงเดิมใช้ไม่ได้แล้ว ต้องล้างทิ้ง
watch(() => props.kind, () => {
  results.value = []
  emit('update:modelValue', { label: text.value, school_id: null, profile_id: null })
})

let timer = null
function onInput() {
  emit('update:modelValue', { label: text.value, school_id: null, profile_id: null })
  if (!searchable.value) return
  clearTimeout(timer)
  timer = setTimeout(search, 300)
}
onBeforeUnmount(() => { clearTimeout(timer); clearTimeout(blurTimer) })

async function search() {
  const q = text.value.trim()
  if (q.length < 2) { results.value = []; open.value = false; return }
  loading.value = true

  if (props.kind === 'school') {
    const { data } = await supabase.from('schools')
      .select('id, name, school_group, district')
      .ilike('name', `%${q}%`).order('name').limit(8)
    results.value = (data || []).map(s => ({
      id: s.id, kind: 'school', label: s.name,
      sub: [s.school_group && `ศูนย์ ${s.school_group}`, s.district && `อ.${s.district}`].filter(Boolean).join(' · '),
    }))
  } else {
    const { data } = await supabase.from('profiles')
      .select('id, full_name, first_name, last_name, title, position, school_name')
      .eq('role', props.kind).limit(8)
    results.value = (data || [])
      .map(p => ({
        id: p.id, kind: 'profile',
        label: `${p.title || ''}${p.first_name || ''}${p.last_name ? ' ' + p.last_name : ''}`.trim() || p.full_name || '',
        sub: [p.position, p.school_name].filter(Boolean).join(' · '),
      }))
      .filter(r => r.label.includes(q) || r.sub.includes(q))
  }

  loading.value = false
  open.value = results.value.length > 0
}

function pick(r) {
  text.value = r.label
  emit('update:modelValue', {
    label: r.label,
    school_id:  r.kind === 'school'  ? r.id : null,
    profile_id: r.kind === 'profile' ? r.id : null,
  })
  open.value = false
  results.value = []
}

/** หน่วงปิดรายการตอน blur เพื่อให้คลิกเลือกทัน — เรียก setTimeout ใน template ไม่ได้ */
let blurTimer = null
function onBlur() {
  clearTimeout(blurTimer)
  blurTimer = setTimeout(() => { open.value = false }, 180)
}

function clearLink() {
  emit('update:modelValue', { label: text.value, school_id: null, profile_id: null })
}
</script>

<template>
  <div class="relative">
    <div class="relative">
      <input v-model="text" @input="onInput" @focus="results.length && (open = true)"
        @blur="onBlur"
        :placeholder="placeholder"
        class="w-full px-3 py-2 pr-24 rounded-xl border border-slate-200 text-sm focus:outline-none focus:border-primary"/>

      <!-- บอกให้ชัดว่าชื่อนี้ผูกกับข้อมูลจริงในระบบแล้ว ไม่ใช่แค่ข้อความ -->
      <span v-if="linked"
        class="absolute right-2 top-1/2 -translate-y-1/2 flex items-center gap-1 text-[10px] font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded-lg">
        เชื่อมข้อมูลแล้ว
        <button type="button" @click="clearLink" class="text-emerald-600 hover:text-red-500" title="ยกเลิกการเชื่อม">✕</button>
      </span>
      <span v-else-if="loading" class="absolute right-3 top-1/2 -translate-y-1/2 text-[10px] text-slate-400">กำลังค้นหา…</span>
    </div>

    <!-- รายการที่ค้นเจอ -->
    <div v-if="open" class="absolute z-30 mt-1 w-full bg-white rounded-xl shadow-lg ring-1 ring-slate-900/[0.08] overflow-hidden max-h-64 overflow-y-auto">
      <button v-for="r in results" :key="r.id" type="button" @mousedown.prevent="pick(r)"
        class="w-full text-left px-3 py-2 hover:bg-primary/5 transition-colors border-b border-slate-100 last:border-0">
        <span class="block text-sm font-bold text-slate-700">{{ r.label }}</span>
        <span v-if="r.sub" class="block text-[11px] text-slate-400">{{ r.sub }}</span>
      </button>
    </div>

    <span v-if="searchable" class="block text-[10px] text-slate-400 mt-1">
      พิมพ์อย่างน้อย 2 ตัวอักษรเพื่อค้นหา · ถ้าไม่มีในระบบให้พิมพ์ชื่อได้เลย
    </span>
  </div>
</template>
