<script setup>
import { onMounted, ref } from 'vue'
import { useRoute } from 'vue-router'
import { supabase } from '../supabase'

const route = useRoute()
const supervisor = ref(null)
const contents = ref([])
const loading = ref(true)

onMounted(async () => {
  const supervisorId = route.params.id
  try {
    // Fetch Profile
    const { data: profileData, error: profileError } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', supervisorId)
      .single()
    
    if (profileError) throw profileError
    supervisor.value = profileData

    // Fetch Contents
    const { data: contentsData, error: contentsError } = await supabase
      .from('contents')
      .select('*')
      .eq('supervisor_id', supervisorId)
      .order('created_at', { ascending: false })
    
    if (contentsError) throw contentsError
    contents.value = contentsData
  } catch (error) {
    console.error('Error fetching data:', error.message)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div v-if="loading" class="flex justify-center items-center py-20">
    <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-500"></div>
  </div>

  <div v-else-if="!supervisor" class="text-center py-20">
    <p class="text-gray-500 text-lg">ไม่พบข้อมูลศึกษานิเทศก์</p>
    <router-link to="/" class="text-blue-600 mt-4 inline-block hover:underline">กลับหน้าแรก</router-link>
  </div>

  <div v-else class="space-y-10 animate-in fade-in duration-500">
    <!-- Header Profile Section -->
    <section class="bg-white rounded-3xl p-8 border border-gray-100 shadow-sm flex flex-col md:flex-row items-center md:items-start gap-8">
      <div class="w-32 h-32 md:w-40 md:h-40 rounded-3xl overflow-hidden bg-gray-50 flex-shrink-0 border-4 border-blue-50 shadow-inner">
        <img v-if="supervisor.avatar_url" :src="supervisor.avatar_url" class="w-full h-full object-cover" />
        <div v-else class="w-full h-full flex items-center justify-center bg-blue-50 text-blue-300">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-20 w-20" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
          </svg>
        </div>
      </div>
      
      <div class="text-center md:text-left space-y-3">
        <h1 class="text-3xl font-extrabold text-gray-900">{{ supervisor.full_name }}</h1>
        <p class="text-xl font-medium text-blue-600">{{ supervisor.position }}</p>
        <div class="pt-4 border-t border-gray-50">
          <h3 class="text-sm font-bold text-gray-400 uppercase tracking-wider mb-2">เขตพื้นที่รับผิดชอบ</h3>
          <p class="text-gray-600 leading-relaxed">{{ supervisor.responsibility_area }}</p>
        </div>
      </div>
    </section>

    <!-- Contents Section -->
    <section class="space-y-6">
      <h2 class="text-2xl font-bold text-gray-800 flex items-center">
        <svg xmlns="http://www.w3.org/2000/svg" class="h-7 w-7 mr-2 text-blue-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10l4 4v10a2 2 0 01-2 2z" />
        </svg>
        ผลงานและเนื้อหาเผยแพร่
      </h2>

      <div v-if="contents.length === 0" class="bg-white rounded-3xl p-20 text-center border border-gray-100">
        <p class="text-gray-400">ยังไม่มีเนื้อหาเผยแพร่ในขณะนี้</p>
      </div>

      <div v-else class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div v-for="content in contents" :key="content.id" class="bg-white rounded-2xl p-6 border border-gray-100 shadow-sm hover:shadow-md transition-all">
          <div class="flex items-start justify-between mb-4">
            <span class="px-3 py-1 rounded-full text-xs font-bold" 
              :class="content.content_type === 'News' ? 'bg-blue-100 text-blue-700' : 'bg-orange-100 text-orange-700'">
              {{ content.content_type }}
            </span>
            <span class="text-xs text-gray-400">{{ new Date(content.created_at).toLocaleDateString('th-TH') }}</span>
          </div>
          <h3 class="text-lg font-bold text-gray-800 mb-4 line-clamp-2 leading-snug">{{ content.title }}</h3>
          <a v-if="content.file_url" :href="content.file_url" target="_blank" class="inline-flex items-center text-sm font-bold text-blue-600 hover:text-blue-800 transition-colors">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14" />
            </svg>
            ดูรายละเอียด/ดาวน์โหลด
          </a>
        </div>
      </div>
    </section>
  </div>
</template>
