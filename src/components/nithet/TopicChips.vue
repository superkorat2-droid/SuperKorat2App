<script setup>
/**
 * TopicChips — ประเด็นการนิเทศ
 *
 * ที่มาของตัวเลือก 3 ทาง โดยไม่ต้องมีหน้าตั้งค่าให้แอดมินดูแล:
 *   1. จากปฏิทิน — ชื่อกิจกรรมที่ผูกอยู่ (ส่งมาทาง prop suggested)
 *   2. ที่เคยใช้บ่อย — view nithet_topic_suggestions ระบบจำเอง
 *   3. พิมพ์เพิ่มเอง — คำใหม่จะถูกจำไปเสนอครั้งหน้าอัตโนมัติ
 *
 * ออกแบบให้กดมากกว่าพิมพ์ เพราะกรอกบนมือถือหน้างานเป็นหลัก
 */
import { ref, computed, onMounted } from 'vue'
import { supabase } from '../../supabase'

const props = defineProps({
  modelValue: { type: Array, default: () => [] },   // string[]
  suggested:  { type: Array, default: () => [] },   // จากปฏิทิน — เสนอขึ้นก่อน
})
const emit = defineEmits(['update:modelValue'])

const known  = ref([])
const draft  = ref('')
const loading = ref(true)

onMounted(async () => {
  const { data } = await supabase
    .from('nithet_topic_suggestions')
    .select('topic, uses')
    .limit(40)
  known.value = (data || []).map(r => r.topic)
  loading.value = false
})

/** เสนอเฉพาะที่ยังไม่ได้เลือก — ของจากปฏิทินขึ้นก่อนเสมอ */
const options = computed(() => {
  const chosen = new Set(props.modelValue)
  const fromEvent = props.suggested.filter(t => t && !chosen.has(t))
  const rest = known.value.filter(t => !chosen.has(t) && !fromEvent.includes(t))
  return [...fromEvent, ...rest].slice(0, 24)
})

function add(topic) {
  const t = String(topic || '').trim()
  if (!t || props.modelValue.includes(t)) return
  emit('update:modelValue', [...props.modelValue, t])
}

function remove(topic) {
  emit('update:modelValue', props.modelValue.filter(t => t !== topic))
}

function addDraft() {
  add(draft.value)
  draft.value = ''
}
</script>

<template>
  <div class="space-y-2">
    <label class="text-[11px] font-bold text-slate-500">ประเด็นการนิเทศ</label>

    <div v-if="modelValue.length" class="flex flex-wrap gap-1.5">
      <span v-for="t in modelValue" :key="t"
        class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-bold bg-blue-100 text-blue-700">
        {{ t }}
        <button type="button" @click="remove(t)" class="hover:text-blue-900" aria-label="เอาออก">×</button>
      </span>
    </div>

    <div class="flex gap-2">
      <input v-model="draft" type="text" placeholder="พิมพ์ประเด็นใหม่แล้วกด Enter"
        @keydown.enter.prevent="addDraft"
        class="flex-1 px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
      <button type="button" @click="addDraft" :disabled="!draft.trim()"
        class="px-3 py-2 rounded-xl text-xs font-bold border-2 border-primary text-primary disabled:opacity-40">เพิ่ม</button>
    </div>

    <div v-if="options.length" class="flex flex-wrap gap-1.5">
      <button v-for="t in options" :key="t" type="button" @click="add(t)"
        class="px-2.5 py-1 rounded-full text-xs border border-slate-200 text-slate-600 hover:border-primary hover:text-primary transition-colors">
        + {{ t }}
      </button>
    </div>
    <p v-else-if="!loading && !modelValue.length" class="text-[11px] text-slate-400">
      ยังไม่มีประเด็นที่เคยใช้ — พิมพ์เพิ่มได้เลย ระบบจะจำไว้เสนอครั้งหน้า
    </p>
  </div>
</template>
