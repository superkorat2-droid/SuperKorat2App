<script setup>
/**
 * VoiceTextarea — ช่องข้อความที่พิมพ์ด้วยเสียงได้
 *
 * ปุ่มไมค์เป็น "ของแถม" ไม่ใช่ทางหลัก — Safari บน iPhone ไม่รองรับ Web Speech API
 * เครื่องที่ไม่รองรับจะซ่อนปุ่มแล้วขึ้นคำแนะนำให้ใช้ไมค์บนแป้นพิมพ์แทน
 * ซึ่งถอดเสียงไทยได้ดีอยู่แล้วและมีอยู่ในทุกเครื่อง
 */
import { computed } from 'vue'
import { useSpeechInput, speechSupported } from '../../composables/useSpeechInput'

const props = defineProps({
  modelValue: { type: String, default: '' },
  label:      { type: String, default: '' },
  placeholder:{ type: String, default: '' },
  rows:       { type: Number, default: 4 },
  hint:       { type: String, default: '' },
})
const emit = defineEmits(['update:modelValue'])

const { listening, error, interim, start, stop } = useSpeechInput()

function toggle() {
  if (listening.value) stop()
  else start(props.modelValue, (text) => emit('update:modelValue', text))
}

const preview = computed(() => (listening.value && interim.value ? interim.value : ''))
</script>

<template>
  <div>
    <div class="flex items-center justify-between gap-2 mb-1">
      <label v-if="label" class="text-[11px] font-bold text-slate-500">{{ label }}</label>
      <button v-if="speechSupported" type="button" @click="toggle"
        :class="['flex items-center gap-1 px-2 py-1 rounded-lg text-[11px] font-bold transition-colors',
          listening ? 'bg-red-500 text-white' : 'text-slate-500 hover:bg-slate-100']">
        <span :class="listening ? 'animate-pulse' : ''">🎤</span>
        {{ listening ? 'กำลังฟัง... กดเพื่อหยุด' : 'พูดแทนพิมพ์' }}
      </button>
    </div>

    <textarea
      :value="modelValue"
      @input="emit('update:modelValue', $event.target.value)"
      :rows="rows"
      :placeholder="placeholder"
      class="w-full min-h-[120px] px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white
             focus:outline-none focus:border-primary"></textarea>

    <p v-if="preview" class="text-[11px] text-slate-400 mt-1 italic">{{ preview }}</p>
    <p v-if="error" class="text-[11px] text-red-500 mt-1">{{ error }}</p>
    <p v-if="!speechSupported" class="text-[11px] text-slate-400 mt-1">
      เครื่องนี้ยังพิมพ์ด้วยเสียงจากเว็บไม่ได้ — ใช้ปุ่มไมค์บนแป้นพิมพ์ของเครื่องแทนได้
    </p>
    <p v-else-if="hint" class="text-[11px] text-slate-400 mt-1">{{ hint }}</p>
  </div>
</template>
