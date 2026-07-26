<script setup>
/**
 * ContentBlockRenderer — แสดงผล content_blocks ของคลังสื่อ/ผลงาน
 *
 * คู่กับ ContentBlockEditor.vue — รองรับ 7 block types ชุดเดียวกัน
 * ใช้ร่วมกัน 2 ที่: MediaDetailView, WorkDetailView
 *
 * หมายเหตุ: หน้า CMS (DynamicPageView) ใช้ block ชุดอื่นที่ใหญ่กว่า (12 ชนิด
 * มี gallery/accordion/button/media-text/youtube) และมี editor ของตัวเอง
 * จึงไม่รวมกับตัวนี้ — ถ้าจะรวมต้องยกเครื่องทั้ง 2 ระบบพร้อมกัน
 */
import { extractDriveId } from '../../composables/useGoogleDrive'

defineProps({
  blocks: { type: Array, default: () => [] },
})

function extractYtId(url) {
  const m = url?.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([^&\n?#]+)/)
  return m?.[1]
}
</script>

<template>
  <div v-if="blocks?.length" class="space-y-4">
    <div v-for="(block, i) in blocks" :key="i">

      <!-- heading -->
      <component :is="`h${block.level || 2}`"
        v-if="block.type === 'heading' && block.text"
        :class="['font-extrabold text-slate-800',
          block.level===2?'text-xl':block.level===3?'text-lg':'text-base']">
        {{ block.text }}
      </component>

      <!-- text -->
      <div v-else-if="block.type === 'text' && block.text"
        class="text-slate-600 leading-relaxed whitespace-pre-line">
        {{ block.text }}
      </div>

      <!-- image -->
      <figure v-else-if="block.type === 'image' && block.url" class="rounded-2xl overflow-hidden">
        <img :src="block.url" :alt="block.alt || ''" class="w-full rounded-2xl"/>
        <figcaption v-if="block.caption" class="text-xs text-center text-slate-400 mt-2">{{ block.caption }}</figcaption>
      </figure>

      <!-- drive embed -->
      <div v-else-if="block.type === 'drive' && block.url" class="rounded-2xl overflow-hidden border border-slate-200">
        <p v-if="block.label" class="text-xs font-bold text-slate-500 px-4 py-2 border-b border-slate-100 bg-slate-50">📄 {{ block.label }}</p>
        <div class="aspect-video bg-slate-900">
          <iframe :src="`https://drive.google.com/file/d/${extractDriveId(block.url)}/preview`"
            class="w-full h-full border-0" allow="autoplay" loading="lazy"/>
        </div>
      </div>

      <!-- embed URL -->
      <div v-else-if="block.type === 'embed' && block.url" class="rounded-2xl overflow-hidden border border-slate-200">
        <p v-if="block.label" class="text-xs font-bold text-slate-500 px-4 py-2 border-b border-slate-100 bg-slate-50">🔗 {{ block.label }}</p>
        <div class="aspect-video bg-slate-900">
          <iframe v-if="extractYtId(block.url)"
            :src="`https://www.youtube.com/embed/${extractYtId(block.url)}`"
            class="w-full h-full border-0" allow="autoplay; encrypted-media" allowfullscreen/>
          <iframe v-else :src="block.url" class="w-full h-full border-0" loading="lazy"/>
        </div>
      </div>

      <!-- html — full doc → srcdoc iframe | snippet → v-html -->
      <div v-else-if="block.type === 'html' && block.code" class="rounded-2xl overflow-hidden">
        <iframe v-if="/<!DOCTYPE|<html/i.test(block.code)"
          :srcdoc="block.code"
          sandbox="allow-scripts allow-same-origin"
          class="w-full border-0 rounded-2xl"
          style="min-height:500px; height:80vh; max-height:900px"
          scrolling="yes"/>
        <div v-else v-html="block.code" class="prose max-w-none"/>
      </div>

      <!-- divider -->
      <hr v-else-if="block.type === 'divider'" class="border-slate-200"/>
    </div>
  </div>
</template>
