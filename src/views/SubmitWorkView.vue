<script setup>
/**
 * SubmitWorkView — /submit-work
 * ฟอร์มให้ "บุคคลภายนอกเขต" ส่งผลงานเข้ามา โดยไม่ต้องมีบัญชี
 *
 * เขียนลงตาราง work_submissions ไม่ใช่ works โดยตรง (ดูเหตุผลใน migration 0061)
 * ทุกอย่างที่กรอกมาไม่ขึ้นเว็บจนกว่า ศน. จะตรวจกับทะเบียนรับหนังสือแล้วอนุมัติ
 *
 * หนังสือนำส่งไม่บังคับกรอก แต่เตือนให้ชัดว่าถ้าไม่มีอาจอนุมัติล่าช้า/ไม่ผ่าน
 */
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '../supabase'
import { useAreaConfig } from '../composables/useAreaConfig'
import PageHero from '../components/PageHero.vue'
import { WORK_TYPES, SUBJECT_GROUPS, GRADES } from '../composables/useWorks'

const router = useRouter()
const { config, fetchConfig } = useAreaConfig()

const ready   = ref(false)
const saving  = ref(false)
const done    = ref(false)
const errMsg  = ref('')

const form = ref({
  submitter_name: '', submitter_position: '', submitter_org: '',
  submitter_email: '', submitter_phone: '',
  letter_url: '', letter_no: '', letter_date: '',
  title: '', description: '', work_type: 'innovation', work_url: '',
  subject_group: '', grade_levels: [], academic_year: '',
})

const enabled = computed(() => config.value?.allow_external_works !== false)
const noLetter = computed(() =>
  !form.value.letter_url.trim() && !form.value.letter_no.trim() && !form.value.letter_date
)

onMounted(async () => { await fetchConfig(); ready.value = true })

function toggleGrade(g) {
  const i = form.value.grade_levels.indexOf(g)
  if (i >= 0) form.value.grade_levels.splice(i, 1)
  else form.value.grade_levels.push(g)
}

/** ตรวจฝั่งหน้าเว็บเพื่อบอกผู้ใช้ให้ชัด — ตัวจริงที่บังคับคือ RLS ใน DB */
function validate() {
  const f = form.value
  if (f.submitter_name.trim().length < 2) return 'กรุณากรอกชื่อ-นามสกุลผู้ส่ง'
  if (f.submitter_org.trim().length < 2)  return 'กรุณากรอกสังกัด/หน่วยงาน'
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(f.submitter_email.trim())) return 'อีเมลไม่ถูกต้อง'
  if (f.title.trim().length < 3)          return 'กรุณากรอกชื่อผลงาน (อย่างน้อย 3 ตัวอักษร)'
  if (!/^https?:\/\//i.test(f.work_url.trim())) return 'ลิงก์ผลงานต้องขึ้นต้นด้วย http:// หรือ https://'
  if (f.letter_url.trim() && !/^https?:\/\//i.test(f.letter_url.trim()))
    return 'ลิงก์หนังสือนำส่งต้องขึ้นต้นด้วย http:// หรือ https://'
  return ''
}

async function submit() {
  errMsg.value = validate()
  if (errMsg.value) return

  saving.value = true
  const f = form.value
  const { error } = await supabase.from('work_submissions').insert({
    submitter_name:     f.submitter_name.trim(),
    submitter_position: f.submitter_position.trim() || null,
    submitter_org:      f.submitter_org.trim(),
    submitter_email:    f.submitter_email.trim(),
    submitter_phone:    f.submitter_phone.trim() || null,
    letter_url:  f.letter_url.trim() || null,
    letter_no:   f.letter_no.trim() || null,
    letter_date: f.letter_date || null,
    title:       f.title.trim(),
    description: f.description.trim() || null,
    work_type:   f.work_type,
    work_url:    f.work_url.trim(),
    subject_group: f.subject_group || null,
    grade_levels:  f.grade_levels.length ? f.grade_levels : null,
    academic_year: f.academic_year.trim() || null,
  })
  saving.value = false

  if (error) {
    // 23505 = ชนกับ unique index กันส่งซ้ำ
    errMsg.value = error.code === '23505'
      ? 'ผลงานชื่อนี้จากอีเมลนี้ถูกส่งเข้ามาแล้ว หากต้องการแก้ไขกรุณาติดต่อกลุ่มนิเทศ'
      : (error.message || 'ส่งไม่สำเร็จ กรุณาลองใหม่')
    return
  }
  done.value = true
  window.scrollTo({ top: 0, behavior: 'smooth' })
}

const inputCls = 'w-full px-3 py-2 rounded-xl border border-slate-200 bg-white text-sm focus:outline-none focus:border-primary'
</script>

<template>
  <div class="font-sarabun min-h-screen">
    <PageHero title="ส่งผลงานเพื่อเผยแพร่" icon="star"
      :subtitle="`สำหรับบุคลากรและหน่วยงานภายนอก ${config?.area_name || ''}`"
      align="center" max-width="4xl"/>

    <div class="max-w-3xl mx-auto px-4 py-6">

      <!-- ปิดรับ -->
      <div v-if="ready && !enabled" class="glass-card p-10 text-center">
        <p class="text-4xl mb-3">🔒</p>
        <p class="font-bold text-slate-700">ขณะนี้ปิดรับผลงานจากภายนอก</p>
        <p class="text-sm text-slate-500 mt-1">กรุณาติดต่อกลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา</p>
        <button @click="router.push('/works')" class="mt-5 px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
          ดูผลงานที่เผยแพร่แล้ว
        </button>
      </div>

      <!-- ส่งสำเร็จ -->
      <div v-else-if="done" class="glass-card p-10 text-center">
        <p class="text-5xl mb-3">✅</p>
        <h2 class="text-xl font-extrabold text-slate-800">ส่งผลงานเรียบร้อยแล้ว</h2>
        <p class="text-sm text-slate-600 mt-2 leading-relaxed">
          ศึกษานิเทศก์จะตรวจสอบผลงานของท่านเทียบกับหนังสือนำส่งที่เขตได้รับและลงทะเบียนไว้<br/>
          เมื่อกระบวนการเรียบร้อย ผลงานจะแสดงบนหน้าเผยแพร่ผลงานของกลุ่มนิเทศ
        </p>
        <p class="text-xs text-slate-400 mt-3">
          กลุ่มนิเทศจะติดต่อกลับทางโทรศัพท์หรือหนังสือราชการตามช่องทางปกติ
        </p>
        <div class="flex flex-wrap justify-center gap-2 mt-6">
          <button @click="router.push('/works')" class="px-5 py-2.5 text-sm font-bold bg-primary text-white rounded-2xl shadow-md hover:-translate-y-0.5 transition-all">
            ดูผลงานที่เผยแพร่แล้ว
          </button>
          <button @click="router.push('/contact')" class="px-5 py-2.5 text-sm font-bold bg-slate-100 text-slate-600 rounded-2xl hover:bg-slate-200 transition-colors">
            ติดต่อกลุ่มนิเทศ
          </button>
        </div>
      </div>

      <!-- ฟอร์ม -->
      <form v-else-if="ready" @submit.prevent="submit" class="space-y-5">

        <div class="glass-tile px-4 py-3 text-sm text-slate-600">
          กรอกข้อมูลให้ครบถ้วน ผลงานจะยัง<b>ไม่แสดงบนเว็บ</b>จนกว่าศึกษานิเทศก์จะตรวจสอบและอนุมัติ
        </div>

        <!-- ผู้ส่ง -->
        <div class="glass-card p-5 space-y-3">
          <p class="font-bold text-slate-700">1. ข้อมูลผู้ส่ง</p>
          <div class="grid sm:grid-cols-2 gap-3">
            <div>
              <label class="text-[11px] font-bold text-slate-500">ชื่อ-นามสกุล *</label>
              <input v-model="form.submitter_name" :class="inputCls" placeholder="เช่น นางสาวสมหญิง ใจดี"/>
            </div>
            <div>
              <label class="text-[11px] font-bold text-slate-500">ตำแหน่ง</label>
              <input v-model="form.submitter_position" :class="inputCls" placeholder="เช่น ครูชำนาญการ"/>
            </div>
            <div class="sm:col-span-2">
              <label class="text-[11px] font-bold text-slate-500">สังกัด/หน่วยงาน *</label>
              <input v-model="form.submitter_org" :class="inputCls" placeholder="เช่น โรงเรียนบ้านหนองบัว สพป.นครราชสีมา เขต 1"/>
            </div>
            <div>
              <label class="text-[11px] font-bold text-slate-500">อีเมล *</label>
              <input v-model="form.submitter_email" type="email" :class="inputCls" placeholder="name@example.com"/>
            </div>
            <div>
              <label class="text-[11px] font-bold text-slate-500">โทรศัพท์</label>
              <input v-model="form.submitter_phone" :class="inputCls" placeholder="08x-xxx-xxxx"/>
            </div>
          </div>
        </div>

        <!-- หนังสือนำส่ง -->
        <div class="glass-card p-5 space-y-3">
          <p class="font-bold text-slate-700">2. หนังสือนำส่งขอเผยแพร่ผลงาน</p>
          <p class="text-xs text-slate-500 -mt-1">
            ใช้เทียบกับหนังสือฉบับจริงที่เขตได้รับและลงทะเบียนไว้ — ทำให้ตรวจสอบและอนุมัติได้เร็ว
          </p>

          <div v-if="noLetter" class="text-xs text-amber-700 bg-amber-50 border border-amber-200 rounded-xl px-3 py-2">
            ⚠️ ยังไม่ได้แนบข้อมูลหนังสือนำส่ง — <b>ส่งได้</b> แต่ศึกษานิเทศก์จะไม่มีหลักฐานเทียบกับทะเบียนรับหนังสือ
            ทำให้<b>อนุมัติล่าช้าหรืออาจไม่ผ่าน</b> แนะนำให้แนบถ้ามี
          </div>

          <div>
            <label class="text-[11px] font-bold text-slate-500">ลิงก์สาธารณะของหนังสือนำส่ง (PDF/Drive)</label>
            <input v-model="form.letter_url" :class="[inputCls, 'font-mono']" placeholder="https://drive.google.com/…"/>
            <p class="text-[10px] text-slate-400 mt-1">ตั้งค่าการแชร์เป็น “ทุกคนที่มีลิงก์” ไม่งั้นเจ้าหน้าที่เปิดไม่ได้</p>
          </div>
          <div class="grid sm:grid-cols-2 gap-3">
            <div>
              <label class="text-[11px] font-bold text-slate-500">เลขที่หนังสือ</label>
              <input v-model="form.letter_no" :class="inputCls" placeholder="เช่น ศธ 04062/1234"/>
            </div>
            <div>
              <label class="text-[11px] font-bold text-slate-500">วันที่ในหนังสือ</label>
              <input v-model="form.letter_date" type="date" :class="inputCls"/>
            </div>
          </div>
        </div>

        <!-- ผลงาน -->
        <div class="glass-card p-5 space-y-3">
          <p class="font-bold text-slate-700">3. ข้อมูลผลงาน</p>
          <div>
            <label class="text-[11px] font-bold text-slate-500">ชื่อผลงาน *</label>
            <input v-model="form.title" :class="inputCls" placeholder="เช่น การพัฒนาทักษะการอ่านด้วยชุดกิจกรรม"/>
          </div>
          <div>
            <label class="text-[11px] font-bold text-slate-500">คำอธิบายย่อ</label>
            <textarea v-model="form.description" rows="3" :class="[inputCls, 'resize-none']"
              placeholder="สรุปสั้นๆ ว่าผลงานนี้เกี่ยวกับอะไร"/>
          </div>
          <div>
            <label class="text-[11px] font-bold text-slate-500">ลิงก์ผลงาน (สาธารณะ) *</label>
            <input v-model="form.work_url" :class="[inputCls, 'font-mono']" placeholder="https://drive.google.com/…"/>
          </div>
          <div>
            <label class="text-[11px] font-bold text-slate-500">ประเภทผลงาน</label>
            <div class="grid grid-cols-2 sm:grid-cols-3 gap-1.5 mt-1">
              <button v-for="t in WORK_TYPES" :key="t.value" type="button" @click="form.work_type = t.value"
                :class="['px-2 py-2 rounded-xl text-xs font-bold border-2 transition-all',
                  form.work_type === t.value ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-600 hover:border-primary/50']">
                {{ t.icon }} {{ t.label }}
              </button>
            </div>
          </div>
          <div class="grid sm:grid-cols-2 gap-3">
            <div>
              <label class="text-[11px] font-bold text-slate-500">กลุ่มสาระ</label>
              <select v-model="form.subject_group" :class="inputCls">
                <option value="">— ไม่ระบุ —</option>
                <option v-for="s in SUBJECT_GROUPS" :key="s" :value="s">{{ s }}</option>
              </select>
            </div>
            <div>
              <label class="text-[11px] font-bold text-slate-500">ปีการศึกษา</label>
              <input v-model="form.academic_year" :class="inputCls" placeholder="2569"/>
            </div>
          </div>
          <div>
            <label class="text-[11px] font-bold text-slate-500">ระดับชั้น</label>
            <div class="flex flex-wrap gap-1.5 mt-1">
              <button v-for="g in GRADES" :key="g" type="button" @click="toggleGrade(g)"
                :class="['px-2.5 py-1 rounded-full text-xs font-bold border transition-colors',
                  form.grade_levels.includes(g) ? 'border-primary bg-primary text-white' : 'border-slate-200 text-slate-500 hover:border-primary/50']">
                {{ g }}
              </button>
            </div>
          </div>
        </div>

        <p v-if="errMsg" class="text-sm text-red-600 bg-red-50 border border-red-200 rounded-xl px-4 py-3">{{ errMsg }}</p>

        <button type="submit" :disabled="saving"
          class="w-full py-3.5 rounded-2xl bg-primary text-white font-bold shadow-md hover:-translate-y-0.5 transition-all disabled:opacity-50">
          {{ saving ? 'กำลังส่ง…' : 'ส่งผลงานเพื่อขอเผยแพร่' }}
        </button>
      </form>
    </div>
  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
</style>
