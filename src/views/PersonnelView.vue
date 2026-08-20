<script setup>
import { ref, computed, onMounted } from 'vue'
import { useAreaConfig } from '../composables/useAreaConfig'
import { usePageHeader } from '../composables/usePageHeader'
import { fetchPersonnel } from '../composables/usePersonnel'
import PageHero from '../components/PageHero.vue'
import PersonnelDirectory from '../components/personnel/PersonnelDirectory.vue'

const { config, fetchConfig } = useAreaConfig()
const header = usePageHeader('personnel', {
  icon: 'users', title: 'ทำเนียบบุคลากร', subtitle: 'บุคลากรกลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา',
  align: 'left',
})
const loading   = ref(true)
const personnel = ref([])

onMounted(async () => {
  fetchConfig()
  const { rows } = await fetchPersonnel()
  personnel.value = rows
  loading.value = false
})

// กลุ่มงาน config — คุมลำดับ/การซ่อนกลุ่ม ส่งต่อให้ PersonnelDirectory
const personnelGroupConfig = computed(() => config.value?.personnel_groups || [])
// หัวข้อบล็อก ผอ.เขต/รอง ผอ./ผอ.กลุ่ม ที่แอดมินตั้งเองได้ (ว่าง = ใช้ค่าเริ่มต้นใน component)
const sectionTitles = computed(() => config.value?.personnel_section_titles || {})
</script>

<template>
  <div class="font-sarabun min-h-screen transition-colors" style="background:radial-gradient(ellipse at top,#f0f4ff 0%,#f8fafc 60%)">

    <!-- Page header -->
    <PageHero v-if="!header.hidden" :title="header.title" :subtitle="header.subtitle"
      :mode="header.mode" :icon="header.icon"
      :media-url="header.mediaUrl" :media-type="header.mediaType" :aspect-ratio="header.aspectRatio"
      size="md" :align="header.align" max-width="6xl"/>

    <div class="max-w-6xl mx-auto px-4 py-8">

      <!-- Loading -->
      <div v-if="loading" class="flex justify-center py-20">
        <div class="w-10 h-10 border-4 border-primary/30 border-t-primary rounded-full animate-spin"></div>
      </div>

      <PersonnelDirectory v-else :personnel="personnel" :group-config="personnelGroupConfig"
        :section-titles="sectionTitles"/>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
