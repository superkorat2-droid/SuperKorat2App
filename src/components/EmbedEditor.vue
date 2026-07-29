<script setup>
/**
 * EmbedEditor — ตั้งค่าเซกชัน "ฝังลิงก์" ของหน้าแรก
 *
 * แก้ object ที่ส่งเข้ามาโดยตรงเหมือน DriveFolderEditor / YoutubeGridEditor
 * (parent ถือ state) — โมดัลเป็น v-if จึงสร้างใหม่ทุกครั้งที่เปิด ไม่มีสถานะค้าง
 */
import { computed } from 'vue'
import { EMBED_TYPES, ASPECT_OPTIONS, detectEmbedType, toEmbedUrl } from '../composables/useEmbed'

const props = defineProps({
  modelValue: { type: Object, required: true },  // { url, embed_type, aspect, caption, full_width, max_width }
})

const cfg = props.modelValue
if (!cfg.aspect) cfg.aspect = '16/9'
if (cfg.full_width === undefined) cfg.full_width = false

// ตรวจชนิดใหม่ทุกครั้งที่ url เปลี่ยน แต่ให้ผู้ใช้เลือกทับเองได้ถ้าเดาผิด
const detected = computed(() => detectEmbedType(cfg.url))
function onUrlInput() { cfg.embed_type = detectEmbedType(cfg.url) }

const activeType = computed(() => cfg.embed_type || detected.value)
const previewUrl = computed(() => cfg.url ? toEmbedUrl(cfg.url, activeType.value) : '')
</script>

<template>
  <div class="space-y-3">
    <!-- ลิงก์ -->
    <div>
      <label class="text-[11px] font-bold text-slate-500">ลิงก์ที่ต้องการฝัง</label>
      <input v-model="cfg.url" @input="onUrlInput" type="url"
        placeholder="วาง URL เช่น YouTube, Google Slides/Docs/Forms/Maps, Drive, Canva, PDF"
        class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white font-mono
               focus:outline-none focus:border-primary"/>
      <p v-if="cfg.url && !activeType" class="text-[11px] text-red-500 mt-1">
        ลิงก์นี้ไม่ถูกต้อง — ต้องขึ้นต้นด้วย http:// หรือ https://
      </p>
    </div>

    <!-- ชนิดที่ตรวจพบ + เลือกทับเองได้ -->
    <div v-if="cfg.url && activeType" class="flex flex-wrap items-center gap-2">
      <span class="text-[11px] font-bold text-slate-500">ตรวจพบ</span>
      <span :class="['text-[11px] font-bold px-2.5 py-1 rounded-full', EMBED_TYPES[activeType]?.color]">
        {{ EMBED_TYPES[activeType]?.label || activeType }}
      </span>
      <select v-model="cfg.embed_type"
        class="ml-auto px-2.5 py-1.5 rounded-xl border border-slate-200 text-xs bg-white focus:outline-none focus:border-primary">
        <option v-for="(v, k) in EMBED_TYPES" :key="k" :value="k">แก้เป็น {{ v.label }}</option>
      </select>
    </div>

    <div class="glass-inset p-3 text-[11px] text-slate-600 leading-relaxed">
      วางลิงก์ปกติที่ก๊อปจากเบราว์เซอร์ได้เลย ระบบแปลงเป็นลิงก์สำหรับฝังให้เอง
      · ไฟล์ Drive/Slides ต้องแชร์แบบ <b>"ทุกคนที่มีลิงก์"</b> ไม่งั้นผู้ชมจะเห็นเป็นช่องว่าง
      · บางเว็บไม่อนุญาตให้ฝัง (X-Frame-Options) กรณีนั้นจะขึ้นเป็นกรอบว่างซึ่งแก้ที่ปลายทางไม่ได้
    </div>

    <!-- สัดส่วน + ความกว้าง -->
    <div class="flex flex-wrap items-center gap-x-5 gap-y-2">
      <div class="flex items-center gap-1.5">
        <span class="text-[11px] font-bold text-slate-500">สัดส่วน</span>
        <select v-model="cfg.aspect"
          class="px-2.5 py-1.5 rounded-xl border border-slate-200 text-xs bg-white focus:outline-none focus:border-primary">
          <option v-for="a in ASPECT_OPTIONS" :key="a.value" :value="a.value">{{ a.label }}</option>
        </select>
      </div>

      <label class="flex items-center gap-2 text-sm text-slate-600 cursor-pointer select-none">
        <input type="checkbox" v-model="cfg.full_width" class="w-4 h-4 rounded accent-[var(--color-primary)]"/>
        เต็มความกว้างจอ
      </label>
    </div>

    <!-- คำอธิบายใต้กรอบ -->
    <div>
      <label class="text-[11px] font-bold text-slate-500">คำอธิบายใต้กรอบ (เว้นว่างได้)</label>
      <input v-model="cfg.caption" type="text" placeholder="เช่น คลิปแนะนำการใช้งานระบบ"
        class="w-full px-3 py-2 rounded-xl border border-slate-200 text-sm bg-white focus:outline-none focus:border-primary"/>
    </div>

    <!-- ตัวอย่างจริง — เห็นเลยว่าฝังได้ไหมก่อนบันทึก -->
    <div v-if="previewUrl">
      <span class="block text-[11px] font-bold text-slate-500 mb-1.5">ตัวอย่าง</span>
      <div class="rounded-2xl overflow-hidden border border-slate-200 bg-slate-50">
        <div :style="{ aspectRatio: cfg.aspect || '16/9' }">
          <iframe :src="previewUrl" class="w-full h-full" frameborder="0"
            allow="autoplay; encrypted-media; fullscreen" allowfullscreen loading="lazy"/>
        </div>
      </div>
      <p class="text-[11px] text-slate-400 mt-1 break-all">ลิงก์ที่ใช้ฝังจริง: {{ previewUrl }}</p>
    </div>
  </div>
</template>
