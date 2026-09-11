<script setup>
/**
 * PlacePicker — เลือกโรงเรียนด้วยการพิมพ์ค้นหา หรือพิมพ์ชื่อสถานที่เองเมื่อไม่ได้ไปโรงเรียน
 *
 * 175 โรงเรียนใน dropdown เลื่อนหาไม่ไหวบนมือถือ จึงใช้พิมพ์ค้นหาแทน
 * และต้องรองรับกรณีไปเป็นวิทยากร/ประชุมนอกเขต ซึ่งไม่มีชื่อในลิสต์
 */
import { ref, computed, onMounted, watch } from 'vue'
import { supabase } from '../../supabase'

const props = defineProps({
  schoolId:  { type: String, default: '' },
  placeName: { type: String, default: '' },
})
const emit = defineEmits(['update:schoolId', 'update:placeName'])

const schools = ref([])
const q = ref('')
const open = ref(false)
// โหมด: เลือกโรงเรียน หรือพิมพ์สถานที่เอง
const mode = ref(props.placeName && !props.schoolId ? 'place' : 'school')

onMounted(async () => {
  const { data } = await supabase
    .from('schools')
    .select('id, name, district, school_group')
    .order('name')
  schools.value = data || []
})

const selected = computed(() => schools.value.find(s => s.id === props.schoolId) || null)

const matches = computed(() => {
  const s = q.value.trim().toLowerCase()
  if (!s) return schools.value.slice(0, 12)
  return schools.value.filter(x => x.name.toLowerCase().includes(s)).slice(0, 20)
})

function pick(s) {
  emit('update:schoolId', s.id)
  emit('update:placeName', '')
  q.value = ''
  open.value = false
}

function clearSchool() {
  emit('update:schoolId', '')
  q.value = ''
}

watch(mode, (m) => {
  // สลับโหมดแล้วล้างอีกฝั่งทิ้ง เพื่อไม่ให้เหลือค่าค้างทั้งสองช่อง
  if (m === 'place') emit('update:schoolId', '')
  else emit('update:placeName', '')
})
</script>

<template>
  <div class="space-y-2">
    <div class="flex items-center justify-between gap-2">
      <label class="text-[11px] font-bold text-slate-500">ไปที่ไหน <span class="text-red-500">*</span></label>
      <div class="flex gap-1 bg-slate-100 p-0.5 rounded-lg">
        <button type="button" @click="mode = 'school'"
          :class="['px-2.5 py-1 text-[11px] font-bold rounded-md transition-colors',
            mode === 'school' ? 'bg-white text-primary shadow-sm' : 'text-slate-500']">โรงเรียน</button>
        <button type="button" @click="mode = 'place'"
          :class="['px-2.5 py-1 text-[11px] font-bold rounded-md transition-colors',
            mode === 'place' ? 'bg-white text-primary shadow-sm' : 'text-slate-500']">สถานที่อื่น</button>
      </div>
    </div>

    <!-- โหมดโรงเรียน -->
    <div v-if="mode === 'school'" class="relative">
      <div v-if="selected"
        class="flex items-center gap-2 px-3 py-2 rounded-xl border border-emerald-200 bg-emerald-50">
        <span class="flex-1 text-sm font-bold text-slate-700">{{ selected.name }}</span>
        <span class="text-[11px] text-slate-500">อ.{{ selected.district }}</span>
        <button type="button" @click="clearSchool" class="text-xs font-bold text-red-500">เปลี่ยน</button>
      </div>

      <template v-else>
        <input v-model="q" type="search" placeholder="พิมพ์ชื่อโรงเรียน เช่น บ้านหนอง"
          @focus="open = true"
          class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
        <div v-if="open && matches.length"
          class="absolute z-20 mt-1 w-full max-h-60 overflow-y-auto rounded-xl border border-slate-200 bg-white shadow-lg divide-y divide-slate-100">
          <button v-for="s in matches" :key="s.id" type="button" @mousedown.prevent="pick(s)"
            class="w-full text-left px-3 py-2 hover:bg-slate-50">
            <span class="block text-sm font-bold text-slate-700">{{ s.name }}</span>
            <span class="block text-[11px] text-slate-400">อ.{{ s.district }} · {{ s.school_group }}</span>
          </button>
        </div>
      </template>
    </div>

    <!-- โหมดสถานที่อื่น -->
    <input v-else
      :value="placeName"
      @input="emit('update:placeName', $event.target.value)"
      type="text" placeholder="เช่น ห้องประชุม สพป.นม.2 / โรงแรม..."
      class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>

    <p class="text-[11px] text-slate-400">
      ไม่ได้ไปโรงเรียน เช่น เป็นวิทยากรหรือประชุมนอกเขต ให้กด "สถานที่อื่น" แล้วพิมพ์ชื่อเอง
    </p>
  </div>
</template>
