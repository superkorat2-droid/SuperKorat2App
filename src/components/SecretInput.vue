<script setup>
/**
 * SecretInput — ช่องกรอกรหัสผ่าน/รหัสลับ พร้อมปุ่มดวงตาเปิด-ปิดการมองเห็น
 *
 * ใช้ทุกที่ที่มีการ "กำหนดรหัส" หรือ "ใส่รหัส" เพื่อให้หน้าตาและพฤติกรรมตรงกันหมด
 * (เดิมมีปุ่มตาแค่ที่หน้าล็อกอินโรงเรียนที่เดียว ที่อื่นพิมพ์แล้วมองไม่เห็นเลย)
 *
 * inheritAttrs: false + v-bind="$attrs" → ส่ง placeholder / required / minlength /
 * autocomplete / @keydown.enter ทะลุไปที่ <input> จริงได้เลย ไม่ต้องประกาศ prop ทีละตัว
 *
 * tabindex="-1" ที่ปุ่ม เพื่อไม่ให้กด Tab จากช่องรหัสแล้วไปติดที่ปุ่มตา
 * (คนกรอกฟอร์มคาดหวังว่า Tab จะไปช่องถัดไป)
 */
import { ref } from 'vue'

defineOptions({ inheritAttrs: false })

defineProps({
  modelValue: { type: String, default: '' },
  /** คลาสของ <input> — ส่งมาให้ตรงกับฟอร์มที่ใช้ เพื่อคงหน้าตาเดิมของแต่ละหน้า */
  inputClass: { type: String, default: '' },
})
defineEmits(['update:modelValue'])

const show = ref(false)

const EYE      = 'M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.964-7.178z'
const EYE_DOT  = 'M15 12a3 3 0 11-6 0 3 3 0 016 0z'
const EYE_OFF  = 'M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88'
</script>

<template>
  <div class="relative">
    <input
      :value="modelValue"
      @input="$emit('update:modelValue', $event.target.value)"
      :type="show ? 'text' : 'password'"
      v-bind="$attrs"
      :class="[inputClass, 'pr-12']"/>

    <button type="button" tabindex="-1"
      @click="show = !show"
      :title="show ? 'ซ่อนรหัส' : 'แสดงรหัส'"
      :aria-label="show ? 'ซ่อนรหัส' : 'แสดงรหัส'"
      :aria-pressed="show"
      class="absolute right-1.5 top-1/2 -translate-y-1/2 w-9 h-9 flex items-center justify-center
             rounded-xl text-slate-400 hover:text-primary hover:bg-primary/10
             active:scale-90 transition-all duration-150">
      <svg class="w-[18px] h-[18px]" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.7">
        <template v-if="show">
          <path stroke-linecap="round" stroke-linejoin="round" :d="EYE_OFF"/>
        </template>
        <template v-else>
          <path stroke-linecap="round" stroke-linejoin="round" :d="EYE"/>
          <path stroke-linecap="round" stroke-linejoin="round" :d="EYE_DOT"/>
        </template>
      </svg>
    </button>
  </div>
</template>
