<script setup>
import { ref, computed, onMounted } from 'vue'
import { RouterLink } from 'vue-router'
import { supabase } from '../supabase'

// ─── Navigation sections ───────────────────────────────────────────────────
const sections = [
  { key: 'home',       icon: '🏠', label: 'หน้าแรก' },
  { key: 'general',   icon: 'ℹ️',  label: 'ข้อมูลทั่วไป' },
  { key: 'curriculum',icon: '📖', label: 'พัฒนาหลักสูตร' },
  { key: 'supervision',icon:'🔍', label: 'นิเทศการศึกษา' },
  { key: 'evaluation',icon: '📊', label: 'วัดและประเมินผล' },
  { key: 'quality',   icon: '⭐', label: 'ประกันคุณภาพ' },
  { key: 'research',  icon: '🔬', label: 'วิจัย สื่อ เทคโนโลยี' },
  { key: 'secretariat',icon:'📋', label: 'ส่งเสริมการบริหาร' },
  { key: 'services',  icon: '⬇️', label: 'บริการและดาวน์โหลด' },
]
const activeSection = ref('home')

// ─── Supabase data ─────────────────────────────────────────────────────────
const supervisors = ref([])
const allContents = ref([])
const loading = ref(true)

onMounted(async () => {
  const [{ data: p }, { data: c }] = await Promise.all([
    supabase.from('profiles').select('id,full_name,position,avatar_url,responsibility_area').order('full_name'),
    supabase.from('contents').select('*').order('created_at', { ascending: false })
  ])
  supervisors.value = p || []
  allContents.value = c || []
  loading.value = false
})

const newsItems  = computed(() => allContents.value.filter(c => c.content_type === 'News').slice(0, 6))
const workItems  = computed(() => allContents.value.filter(c => c.content_type === 'Work').slice(0, 6))

// ─── Section 1 – Home ──────────────────────────────────────────────────────
const activeNewsTab = ref('pr')
const newsTabs = [
  { key: 'pr',    label: 'ข่าวประชาสัมพันธ์' },
  { key: 'nitet', label: 'ข่าวการนิเทศ' },
  { key: 'train', label: 'ข่าวอบรมสัมมนา' },
]

const quickWins = [
  { icon: '🎯', title: 'เด็กทุกคนต้องอ่านออกเขียนได้', desc: 'ยกระดับทักษะการอ่านเขียนตั้งแต่ชั้นประถมศึกษาปีที่ 1', color: 'from-blue-500 to-blue-700' },
  { icon: '🧮', title: 'Math for ALL', desc: 'พัฒนาทักษะคณิตศาสตร์ผ่านสื่อและกิจกรรมเชิงรุก', color: 'from-indigo-500 to-indigo-700' },
  { icon: '💻', title: 'Coding & Digital Skill', desc: 'ส่งเสริมทักษะดิจิทัลและการคิดเชิงคำนวณ', color: 'from-violet-500 to-violet-700' },
  { icon: '🌿', title: 'โรงเรียนสิ่งแวดล้อม', desc: 'สร้างจิตสำนึกด้านสิ่งแวดล้อมและพลังงานสะอาด', color: 'from-emerald-500 to-emerald-700' },
]

const emphases = [
  { icon: '📚', title: 'ยกระดับผลสัมฤทธิ์', desc: 'O-NET / NT / RT ให้สูงกว่าค่าเฉลี่ยระดับชาติ' },
  { icon: '🏫', title: 'โรงเรียนคุณภาพ', desc: 'พัฒนาโรงเรียนทุกแห่งให้ผ่านเกณฑ์มาตรฐาน' },
  { icon: '👩‍🏫', title: 'พัฒนาครูมืออาชีพ', desc: 'Active Learning, Coaching & Mentoring' },
  { icon: '🤝', title: 'มีส่วนร่วมชุมชน', desc: 'เสริมพลังภาคีเครือข่ายและผู้ปกครอง' },
]

const dashStats = [
  { icon: '🏫', label: 'โรงเรียนในสังกัด', value: '84', unit: 'แห่ง', color: 'text-blue-600', bg: 'bg-blue-50' },
  { icon: '👨‍🎓', label: 'นักเรียนทั้งหมด', value: '32,150', unit: 'คน', color: 'text-emerald-600', bg: 'bg-emerald-50' },
  { icon: '👩‍🏫', label: 'ครูและบุคลากร', value: '2,340', unit: 'คน', color: 'text-violet-600', bg: 'bg-violet-50' },
  { icon: '📊', label: 'O-NET เฉลี่ย', value: '42.5', unit: 'คะแนน', color: 'text-rose-600', bg: 'bg-rose-50' },
  { icon: '✅', label: 'ผ่านประเมิน สมศ.', value: '76', unit: 'แห่ง', color: 'text-amber-600', bg: 'bg-amber-50' },
  { icon: '📈', label: 'NT เฉลี่ย ป.3', value: '51.2', unit: 'คะแนน', color: 'text-indigo-600', bg: 'bg-indigo-50' },
]

// ─── Section 2 – General ───────────────────────────────────────────────────
const visionMission = [
  { icon: '👁️', title: 'วิสัยทัศน์', color: 'border-blue-500 bg-blue-50',
    text: 'กลุ่มนิเทศ ติดตาม และประเมินผลการจัดการศึกษา มุ่งสู่องค์กรชั้นนำด้านการนิเทศการศึกษา เพื่อยกระดับคุณภาพการเรียนรู้ของผู้เรียนสู่มาตรฐานสากล' },
  { icon: '🎯', title: 'พันธกิจ', color: 'border-indigo-500 bg-indigo-50',
    text: 'นิเทศ ติดตาม และประเมินผลการจัดการศึกษาอย่างเป็นระบบ พัฒนาหลักสูตรและกระบวนการเรียนรู้ที่ส่งเสริมสมรรถนะผู้เรียน ส่งเสริมการวิจัยและนวัตกรรมทางการศึกษา' },
  { icon: '🏆', title: 'เป้าประสงค์', color: 'border-violet-500 bg-violet-50',
    text: 'สถานศึกษาทุกแห่งได้รับการนิเทศอย่างทั่วถึงและมีคุณภาพ ผู้เรียนมีสมรรถนะที่สำคัญตามหลักสูตร ครูมีความเชี่ยวชาญด้านการจัดการเรียนรู้เชิงรุก' },
]

const orgChart = [
  { title: 'ผู้อำนวยการกลุ่มนิเทศฯ', color: 'bg-blue-600 text-white', children: [
    { title: 'งานพัฒนาหลักสูตร', color: 'bg-blue-100 text-blue-800' },
    { title: 'งานนิเทศการศึกษา', color: 'bg-indigo-100 text-indigo-800' },
    { title: 'งานวัดและประเมินผล', color: 'bg-violet-100 text-violet-800' },
    { title: 'งานประกันคุณภาพ', color: 'bg-emerald-100 text-emerald-800' },
    { title: 'งานวิจัย สื่อ เทคโนโลยี', color: 'bg-amber-100 text-amber-800' },
    { title: 'งานส่งเสริมการบริหาร', color: 'bg-rose-100 text-rose-800' },
  ]}
]

const schoolStats = [
  { label: 'โรงเรียนขนาดใหญ่ (>499)', value: '8', icon: '🏢' },
  { label: 'โรงเรียนขนาดกลาง (120-499)', value: '31', icon: '🏫' },
  { label: 'โรงเรียนขนาดเล็ก (<120)', value: '45', icon: '🏡' },
  { label: 'โรงเรียนในโครงการพิเศษ', value: '12', icon: '⭐' },
]

// ─── Section 3 – Curriculum ────────────────────────────────────────────────
const curriculumCards = [
  { icon: '📜', title: 'หลักสูตรแกนกลาง', desc: 'เอกสารตัวชี้วัดและสาระการเรียนรู้แกนกลาง พ.ศ. 2551 (ฉบับปรับปรุง พ.ศ. 2560)', color: 'bg-blue-50 border-blue-200',
    items: ['ตัวชี้วัดและสาระการเรียนรู้แกนกลาง', 'คู่มือการใช้หลักสูตร', 'แนวการจัดทำหน่วยการเรียนรู้'] },
  { icon: '🌳', title: 'หลักสูตรท้องถิ่น', desc: 'แหล่งเรียนรู้และภูมิปัญญาท้องถิ่นในเขตพื้นที่', color: 'bg-emerald-50 border-emerald-200',
    items: ['แหล่งเรียนรู้ในชุมชน', 'ภูมิปัญญาท้องถิ่น', 'หลักสูตรสถานศึกษา (ตัวอย่าง)'] },
  { icon: '🧒', title: 'การศึกษาปฐมวัย', desc: 'แนวทางการจัดการศึกษาสำหรับเด็กปฐมวัย (อายุ 3-6 ปี)', color: 'bg-amber-50 border-amber-200',
    items: ['หลักสูตรการศึกษาปฐมวัย พ.ศ. 2560', 'คู่มือครูปฐมวัย', 'สื่อและกิจกรรมปฐมวัย'] },
  { icon: '♿', title: 'การศึกษาพิเศษ', desc: 'การจัดการเรียนรวมและเด็กที่มีความต้องการพิเศษ', color: 'bg-rose-50 border-rose-200',
    items: ['แนวทางการเรียนรวม', 'แผนการจัดการศึกษาเฉพาะบุคคล (IEP)', 'เด็กที่มีความสามารถพิเศษ (Gifted)'] },
]

// ─── Section 4 – Supervision ───────────────────────────────────────────────
const subjectGroups = [
  { icon: '🇹🇭', title: 'ภาษาไทย',           color: 'bg-red-50 text-red-700 border-red-200' },
  { icon: '🔢', title: 'คณิตศาสตร์',         color: 'bg-blue-50 text-blue-700 border-blue-200' },
  { icon: '🔬', title: 'วิทยาศาสตร์และเทคโนโลยี', color: 'bg-emerald-50 text-emerald-700 border-emerald-200' },
  { icon: '🌍', title: 'สังคมศึกษาฯ',        color: 'bg-amber-50 text-amber-700 border-amber-200' },
  { icon: '⚽', title: 'สุขศึกษาและพลศึกษา', color: 'bg-green-50 text-green-700 border-green-200' },
  { icon: '🎨', title: 'ศิลปะ',              color: 'bg-pink-50 text-pink-700 border-pink-200' },
  { icon: '🔨', title: 'การงานอาชีพ',        color: 'bg-orange-50 text-orange-700 border-orange-200' },
  { icon: '🇬🇧', title: 'ภาษาต่างประเทศ',    color: 'bg-indigo-50 text-indigo-700 border-indigo-200' },
]

const coachingItems = [
  { icon: '📗', title: 'คู่มือการเป็นพี่เลี้ยง', desc: 'แนวทาง Coaching & Mentoring สำหรับศึกษานิเทศก์' },
  { icon: '🎥', title: 'คลิปวิดีโอการสาธิตสอน', desc: 'Best Practice จากครูต้นแบบ' },
  { icon: '📝', title: 'แบบบันทึกการนิเทศ', desc: 'แบบฟอร์มการนิเทศก์ Classroom Observation' },
  { icon: '🤝', title: 'PLC ชุมชนการเรียนรู้', desc: 'แนวทางการจัดกิจกรรม PLC สำหรับโรงเรียน' },
]

// ─── Section 5 – Evaluation ────────────────────────────────────────────────
const nationalTests = [
  { abbr: 'RT',    full: 'Reading Test',        grade: 'ป.1',  color: 'bg-blue-600',   icon: '📖',
    desc: 'ทดสอบความสามารถด้านการอ่านของนักเรียนชั้นประถมศึกษาปีที่ 1',
    score: '68.5%', change: '+3.2' },
  { abbr: 'NT',    full: 'National Test',        grade: 'ป.3',  color: 'bg-indigo-600', icon: '✏️',
    desc: 'ทดสอบคุณภาพการศึกษาระดับชาติขั้นพื้นฐาน ชั้น ป.3',
    score: '51.2', change: '+1.8' },
  { abbr: 'O-NET', full: 'Ordinary National Ed.',grade: 'ป.6/ม.3',color:'bg-violet-600',icon: '🎓',
    desc: 'การทดสอบทางการศึกษาระดับชาติขั้นพื้นฐาน โดย สทศ.',
    score: '42.5', change: '+0.9' },
  { abbr: 'PISA',  full: 'Programme Intl. Std.', grade: 'อายุ 15',color:'bg-rose-600', icon: '🌐',
    desc: 'การประเมินผลนักเรียนนานาชาติ โดย OECD',
    score: '393', change: '+5' },
]

const reportSystems = [
  { icon: '📊', title: 'SGS', desc: 'ระบบบริหารผลการเรียน (School Grading System)', href: '#' },
  { icon: '🐱', title: 'CAT', desc: 'ระบบประเมินด้วย Computer Adaptive Test', href: '#' },
  { icon: '📋', title: 'BEST', desc: 'ระบบรายงานผลการทดสอบ O-NET / NT', href: '#' },
  { icon: '🔗', title: 'สทศ.', desc: 'สถาบันทดสอบทางการศึกษาแห่งชาติ', href: '#' },
]

// ─── Section 6 – Quality Assurance ────────────────────────────────────────
const qaCards = [
  { icon: '🏠', title: 'ประกันคุณภาพภายใน (IQA)', color: 'border-l-blue-500',
    items: ['คู่มือการเขียน SAR', 'แนวทางการติดตามตรวจสอบ IQA', 'มาตรฐานการศึกษาขั้นพื้นฐาน', 'เกณฑ์การประเมินระดับคุณภาพ'] },
  { icon: '🔎', title: 'ประกันคุณภาพภายนอก (EQA)', color: 'border-l-emerald-500',
    items: ['ข้อมูลการประเมินจาก สมศ. รอบ 4', 'ผลการประเมินคุณภาพภายนอก', 'แนวทางการเตรียมรับการประเมิน', 'รายงานสรุปผลการประเมิน'] },
  { icon: '📐', title: 'มาตรฐานการศึกษา', color: 'border-l-violet-500',
    items: ['มาตรฐานที่ 1: คุณภาพผู้เรียน', 'มาตรฐานที่ 2: กระบวนการบริหารและการจัดการ', 'มาตรฐานที่ 3: กระบวนการจัดการเรียนการสอน', 'เกณฑ์มาตรฐานสถานศึกษา'] },
]

// ─── Section 7 – Research & Technology ───────────────────────────────────
const researchItems = [
  { icon: '📄', title: 'วิจัยชั้นเรียน ปี 2567', author: 'นายสมชาย ใจดี', subject: 'คณิตศาสตร์' },
  { icon: '📄', title: 'วิจัยพัฒนาทักษะการอ่าน', author: 'นางสาวมานี มีสุข', subject: 'ภาษาไทย' },
  { icon: '📄', title: 'นวัตกรรม STEM โรงเรียนขนาดเล็ก', author: 'นายวิชัย แสงทอง', subject: 'วิทยาศาสตร์' },
]

const mediaLinks = [
  { icon: '📺', title: 'DLTV', desc: 'การศึกษาทางไกลผ่านดาวเทียม วังไกลกังวล', href: '#', color: 'bg-blue-50 text-blue-700' },
  { icon: '💻', title: 'DLIT', desc: 'การศึกษาทางไกลผ่านเทคโนโลยีสารสนเทศ', href: '#', color: 'bg-indigo-50 text-indigo-700' },
  { icon: '🎬', title: 'Obec Content Center', desc: 'คลังสื่อดิจิทัลสำนักงานคณะกรรมการการศึกษา', href: '#', color: 'bg-violet-50 text-violet-700' },
  { icon: '🎓', title: 'Thai MOOC', desc: 'มหาวิทยาลัยไซเบอร์ไทย (TCU)', href: '#', color: 'bg-emerald-50 text-emerald-700' },
]

const paSteps = [
  { step: '1', title: 'จัดทำข้อตกลง PA', desc: 'กำหนดเป้าหมายและตัวชี้วัดผลงานร่วมกับผู้บังคับบัญชา' },
  { step: '2', title: 'ดำเนินการตามข้อตกลง', desc: 'ปฏิบัติงานตามแผนที่กำหนด พร้อมบันทึกหลักฐาน' },
  { step: '3', title: 'ประเมินผลการพัฒนางาน', desc: 'ประเมินผลตามช่วงเวลาที่กำหนด (ครั้งที่ 1 และ 2)' },
  { step: '4', title: 'ยื่นขอวิทยฐานะ', desc: 'ส่งเอกสารขอรับการประเมินวิทยฐานะในระบบ DPA' },
]

// ─── Section 8 – Secretariat ──────────────────────────────────────────────
const ktpnMembers = [
  { role: 'ประธาน ก.ต.ป.น.', name: 'นายสมศักดิ์ ภูมิศาสตร์', type: 'ผู้แทนผู้บริหาร' },
  { role: 'กรรมการ', name: 'นางสาวอรทัย วิชาการ', type: 'ผู้ทรงคุณวุฒิ' },
  { role: 'กรรมการ', name: 'นายธนกร ศึกษาดี', type: 'ผู้แทนผู้ปกครอง' },
  { role: 'กรรมการและเลขานุการ', name: 'นายอภิชาต นิเทศก์', type: 'ศึกษานิเทศก์' },
]

const specialProjects = [
  { icon: '🏆', title: 'โรงเรียนคุณภาพ', tag: 'สพฐ.', desc: '84 โรงเรียน พัฒนาตามมาตรฐาน 4 ด้าน', color: 'bg-amber-50 border-amber-200' },
  { icon: '🚻', title: 'สุขาดีมีความสุข', tag: 'กระทรวง', desc: 'พัฒนาห้องน้ำโรงเรียนให้สะอาดและปลอดภัย', color: 'bg-emerald-50 border-emerald-200' },
  { icon: '📱', title: 'One Tablet Per Child', tag: 'ดิจิทัล', desc: 'จัดหาอุปกรณ์ดิจิทัลเพื่อการเรียนรู้', color: 'bg-blue-50 border-blue-200' },
  { icon: '🤸', title: 'เด็กไทยสุขภาพดี', tag: 'สุขภาพ', desc: 'ส่งเสริมการออกกำลังกายและโภชนาการ', color: 'bg-rose-50 border-rose-200' },
]

// ─── Section 9 – Services ─────────────────────────────────────────────────
const formDownloads = [
  { icon: '📝', title: 'แบบคำร้องทั่วไป', size: '45 KB', type: 'DOCX' },
  { icon: '📋', title: 'แบบฟอร์มขอรับการนิเทศ', size: '62 KB', type: 'PDF' },
  { icon: '📊', title: 'แบบรายงานผลการนิเทศ', size: '120 KB', type: 'XLSX' },
  { icon: '📄', title: 'แบบบันทึก Classroom Observation', size: '80 KB', type: 'PDF' },
  { icon: '📑', title: 'แบบประเมิน SAR โรงเรียน', size: '250 KB', type: 'DOCX' },
  { icon: '🗂️', title: 'แบบฟอร์มข้อตกลง PA', size: '95 KB', type: 'DOCX' },
]

const eServices = [
  { icon: '📅', title: 'ระบบจองศึกษานิเทศก์', desc: 'นัดหมายรับการนิเทศออนไลน์', href: '#', color: 'bg-blue-600' },
  { icon: '🖥️', title: 'ระบบนิเทศออนไลน์', desc: 'แพลตฟอร์มนิเทศผ่านระบบ Video Conference', href: '#', color: 'bg-indigo-600' },
  { icon: '📚', title: 'ระบบ SAR Online', desc: 'รายงานการประเมินตนเองออนไลน์', href: '#', color: 'bg-violet-600' },
  { icon: '🎓', title: 'ระบบลงทะเบียนอบรม', desc: 'สมัครเข้าร่วมการอบรมสัมมนา', href: '#', color: 'bg-emerald-600' },
]

const faqs = ref([
  { q: 'จะขอรับการนิเทศต้องทำอย่างไร?', a: 'ติดต่อศึกษานิเทศก์ผู้รับผิดชอบโดยตรง หรือกรอกแบบฟอร์มขอรับการนิเทศและส่งมาที่กลุ่มนิเทศฯ', open: false },
  { q: 'เอกสารการประเมิน IQA ต้องส่งเมื่อไร?', a: 'โรงเรียนต้องส่ง SAR ภายใน 90 วันหลังสิ้นปีการศึกษา หรือตามที่สำนักงานเขตพื้นที่กำหนด', open: false },
  { q: 'ครูต้องการคำปรึกษาการทำวิทยฐานะ (PA) ติดต่อใคร?', a: 'ติดต่อกลุ่มงานวิจัย สื่อ และเทคโนโลยี หรือศึกษานิเทศก์ผู้รับผิดชอบกลุ่มสาระในโรงเรียนของท่าน', open: false },
  { q: 'แบบทดสอบ NT/O-NET ได้จากไหน?', a: 'ดาวน์โหลดแนวข้อสอบและสรุปผลได้ที่กลุ่มงานวัดและประเมินผล หรือเว็บไซต์ สทศ. โดยตรง', open: false },
])
function toggleFaq(i) { faqs.value[i].open = !faqs.value[i].open }

function formatDate(iso) {
  return new Date(iso).toLocaleDateString('th-TH', { year: 'numeric', month: 'short', day: 'numeric' })
}
</script>

<template>
  <div class="font-sarabun text-slate-800 bg-white min-h-screen">

    <!-- ═══ HERO ═══════════════════════════════════════════════════════════ -->
    <section class="relative bg-gradient-to-br from-blue-800 via-blue-700 to-indigo-800 overflow-hidden">
      <div class="absolute inset-0 opacity-10">
        <svg width="100%" height="100%"><defs><pattern id="g" width="40" height="40" patternUnits="userSpaceOnUse"><path d="M40 0L0 0 0 40" fill="none" stroke="white" stroke-width="1"/></pattern></defs><rect width="100%" height="100%" fill="url(#g)"/></svg>
      </div>
      <div class="relative max-w-7xl mx-auto px-4 py-14 md:py-20 text-white">
        <span class="inline-flex items-center gap-2 bg-white/20 backdrop-blur-sm px-4 py-1.5 rounded-full text-xs font-semibold mb-5">🏛️ สำนักงานเขตพื้นที่การศึกษา</span>
        <h1 class="text-2xl md:text-4xl font-extrabold leading-tight mb-3 drop-shadow-sm">
          กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา
        </h1>
        <p class="text-blue-100 text-base md:text-lg max-w-2xl">
          มุ่งมั่นพัฒนาคุณภาพการศึกษา นิเทศ ติดตาม ส่งเสริมและสนับสนุนการจัดการเรียนการสอน เพื่อยกระดับผลสัมฤทธิ์ทางการเรียน
        </p>
      </div>
      <div class="absolute bottom-0 left-0 right-0">
        <svg viewBox="0 0 1440 40" fill="none"><path d="M0 40L1440 40L1440 10C1200 40 960 0 720 15C480 30 240 0 0 10Z" fill="white"/></svg>
      </div>
    </section>

    <!-- ═══ STICKY SECTION NAV ═══════════════════════════════════════════ -->
    <nav class="sticky top-[80px] z-40 bg-white border-b border-slate-200 shadow-sm">
      <div class="max-w-7xl mx-auto px-2">
        <div class="flex overflow-x-auto gap-1 py-2 scrollbar-none">
          <button
            v-for="s in sections" :key="s.key"
            @click="activeSection = s.key"
            :class="[
              'flex-shrink-0 flex items-center gap-1.5 px-4 py-2 rounded-xl text-sm font-bold transition-all whitespace-nowrap',
              activeSection === s.key
                ? 'bg-blue-600 text-white shadow-md shadow-blue-200'
                : 'text-slate-600 hover:bg-slate-100 hover:text-blue-600'
            ]">
            <span>{{ s.icon }}</span>
            <span class="hidden sm:inline">{{ s.label }}</span>
          </button>
        </div>
      </div>
    </nav>

    <!-- ═══ CONTENT ════════════════════════════════════════════════════════ -->
    <div class="max-w-7xl mx-auto px-4 py-10">

      <!-- ── SECTION 1: หน้าแรก ─────────────────────────────────────────── -->
      <div v-if="activeSection === 'home'" class="space-y-12">

        <!-- นโยบายเร่งด่วน -->
        <div>
          <div class="flex items-center gap-3 mb-6">
            <div class="w-1 h-8 bg-blue-600 rounded-full"></div>
            <div>
              <p class="text-xs text-blue-600 font-bold uppercase tracking-widest">Quick Win Policy</p>
              <h2 class="text-2xl font-extrabold text-slate-900">นโยบายเร่งด่วน</h2>
            </div>
          </div>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div v-for="w in quickWins" :key="w.title"
              :class="`bg-gradient-to-br ${w.color} text-white rounded-2xl p-6 hover:shadow-xl hover:-translate-y-1 transition-all`">
              <div class="text-4xl mb-3">{{ w.icon }}</div>
              <h3 class="font-extrabold text-lg leading-snug mb-2">{{ w.title }}</h3>
              <p class="text-white/80 text-sm leading-relaxed">{{ w.desc }}</p>
            </div>
          </div>
        </div>

        <!-- จุดเน้นของเขตพื้นที่ -->
        <div>
          <div class="flex items-center gap-3 mb-6">
            <div class="w-1 h-8 bg-indigo-600 rounded-full"></div>
            <div>
              <p class="text-xs text-indigo-600 font-bold uppercase tracking-widest">Area Emphasis</p>
              <h2 class="text-2xl font-extrabold text-slate-900">จุดเน้นของเขตพื้นที่</h2>
            </div>
          </div>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div v-for="e in emphases" :key="e.title"
              class="bg-white border border-slate-100 rounded-2xl p-5 shadow-sm hover:shadow-md hover:-translate-y-0.5 transition-all text-center">
              <div class="text-3xl mb-3">{{ e.icon }}</div>
              <h3 class="font-bold text-slate-800 text-sm mb-1">{{ e.title }}</h3>
              <p class="text-xs text-slate-500 leading-relaxed">{{ e.desc }}</p>
            </div>
          </div>
        </div>

        <!-- News Update -->
        <div>
          <div class="flex items-center justify-between mb-6 flex-wrap gap-3">
            <div class="flex items-center gap-3">
              <div class="w-1 h-8 bg-rose-500 rounded-full"></div>
              <div>
                <p class="text-xs text-rose-500 font-bold uppercase tracking-widest">News Update</p>
                <h2 class="text-2xl font-extrabold text-slate-900">ข่าวสาร</h2>
              </div>
            </div>
            <div class="flex gap-1 bg-slate-100 p-1 rounded-2xl">
              <button v-for="t in newsTabs" :key="t.key" @click="activeNewsTab = t.key"
                :class="['px-4 py-1.5 rounded-xl text-xs font-bold transition-all', activeNewsTab === t.key ? 'bg-white text-blue-700 shadow' : 'text-slate-500 hover:text-slate-700']">
                {{ t.label }}
              </button>
            </div>
          </div>

          <div v-if="loading" class="flex justify-center py-10">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          </div>

          <!-- เมื่อมีข้อมูลจาก Supabase -->
          <div v-else-if="newsItems.length > 0" class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div v-for="item in newsItems" :key="item.id"
              class="bg-white border border-slate-100 rounded-2xl p-5 shadow-sm hover:shadow-md transition-all group">
              <div class="flex justify-between items-center mb-3">
                <span class="px-2.5 py-1 bg-blue-100 text-blue-700 text-[10px] font-bold rounded-full">ข่าวสาร</span>
                <span class="text-[10px] text-slate-400">{{ formatDate(item.created_at) }}</span>
              </div>
              <h3 class="font-bold text-slate-800 text-sm leading-snug line-clamp-3 group-hover:text-blue-700 transition-colors">{{ item.title }}</h3>
              <a v-if="item.file_url" :href="item.file_url" target="_blank" class="mt-3 inline-flex items-center gap-1 text-xs font-bold text-blue-600 hover:underline">อ่านเพิ่มเติม →</a>
            </div>
          </div>

          <!-- Mock ถ้ายังไม่มีข้อมูล -->
          <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div v-for="n in 3" :key="n" class="bg-white border border-slate-100 rounded-2xl p-5 shadow-sm">
              <div class="flex justify-between items-center mb-3">
                <span class="px-2.5 py-1 bg-blue-100 text-blue-700 text-[10px] font-bold rounded-full">ข่าวสาร</span>
                <span class="text-[10px] text-slate-400">21 เม.ย. 2568</span>
              </div>
              <div class="h-3 bg-slate-100 rounded-full mb-2 w-full"></div>
              <div class="h-3 bg-slate-100 rounded-full mb-2 w-4/5"></div>
              <div class="h-3 bg-slate-100 rounded-full w-2/3"></div>
              <p class="mt-3 text-xs text-slate-400">(ยังไม่มีข้อมูล)</p>
            </div>
          </div>
        </div>

        <!-- Data Dashboard -->
        <div>
          <div class="flex items-center gap-3 mb-6">
            <div class="w-1 h-8 bg-emerald-600 rounded-full"></div>
            <div>
              <p class="text-xs text-emerald-600 font-bold uppercase tracking-widest">Data Dashboard</p>
              <h2 class="text-2xl font-extrabold text-slate-900">สถิติสำคัญ</h2>
            </div>
          </div>
          <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
            <div v-for="s in dashStats" :key="s.label"
              :class="[s.bg, 'rounded-2xl p-5 flex flex-col items-center text-center border border-white shadow-sm hover:shadow-md transition-all']">
              <span class="text-3xl mb-2">{{ s.icon }}</span>
              <span :class="['text-2xl font-extrabold', s.color]">{{ s.value }}</span>
              <span class="text-xs text-slate-500 mt-0.5">{{ s.unit }}</span>
              <span class="text-[10px] text-slate-400 mt-1 leading-tight text-center">{{ s.label }}</span>
            </div>
          </div>
        </div>
      </div>

      <!-- ── SECTION 2: ข้อมูลทั่วไป ───────────────────────────────────── -->
      <div v-if="activeSection === 'general'" class="space-y-12">

        <!-- วิสัยทัศน์ พันธกิจ เป้าประสงค์ -->
        <div>
          <h2 class="text-2xl font-extrabold text-slate-900 mb-6">วิสัยทัศน์ พันธกิจ เป้าประสงค์</h2>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <div v-for="vm in visionMission" :key="vm.title"
              :class="['rounded-2xl border-2 p-6 h-full', vm.color]">
              <div class="text-4xl mb-3">{{ vm.icon }}</div>
              <h3 class="font-extrabold text-lg text-slate-800 mb-3">{{ vm.title }}</h3>
              <p class="text-sm text-slate-600 leading-relaxed">{{ vm.text }}</p>
            </div>
          </div>
        </div>

        <!-- โครงสร้างการบริหาร -->
        <div>
          <h2 class="text-2xl font-extrabold text-slate-900 mb-6">โครงสร้างการบริหาร</h2>
          <div class="bg-slate-50 rounded-3xl p-8 border border-slate-100">
            <div class="flex flex-col items-center gap-6">
              <div class="bg-blue-600 text-white px-8 py-3 rounded-2xl font-extrabold text-center shadow-lg shadow-blue-200">
                ผู้อำนวยการกลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา
              </div>
              <div class="w-px h-6 bg-slate-300"></div>
              <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-3 w-full">
                <div v-for="g in orgChart[0].children" :key="g.title"
                  :class="['rounded-xl px-3 py-3 text-xs font-bold text-center border', g.color]">
                  {{ g.title }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- ทำเนียบบุคลากร -->
        <div>
          <h2 class="text-2xl font-extrabold text-slate-900 mb-6">ทำเนียบบุคลากร</h2>
          <div v-if="loading" class="flex justify-center py-10">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
          </div>
          <div v-else-if="supervisors.length === 0" class="text-center py-10 text-slate-400">ยังไม่มีข้อมูลบุคลากร</div>
          <div v-else class="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5 gap-4">
            <RouterLink v-for="sv in supervisors" :key="sv.id" :to="`/supervisor/${sv.id}`"
              class="group flex flex-col items-center p-4 bg-white rounded-2xl border border-slate-100 shadow-sm hover:shadow-lg hover:-translate-y-1 transition-all text-center">
              <div class="w-16 h-16 rounded-xl overflow-hidden bg-blue-50 mb-3 border-2 border-blue-100 group-hover:border-blue-400 transition-colors">
                <img v-if="sv.avatar_url" :src="sv.avatar_url" class="w-full h-full object-cover" />
                <div v-else class="w-full h-full flex items-center justify-center text-2xl">👤</div>
              </div>
              <p class="font-bold text-xs text-slate-800 group-hover:text-blue-700 transition-colors line-clamp-2 leading-snug">{{ sv.full_name }}</p>
              <p class="text-[10px] text-slate-400 mt-1 line-clamp-2">{{ sv.position }}</p>
            </RouterLink>
          </div>
        </div>

        <!-- สถิติสถานศึกษา -->
        <div>
          <h2 class="text-2xl font-extrabold text-slate-900 mb-6">ข้อมูลสารสนเทศสถานศึกษา</h2>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <div v-for="s in schoolStats" :key="s.label"
              class="bg-white border border-slate-100 rounded-2xl p-6 text-center shadow-sm hover:shadow-md transition-all">
              <div class="text-3xl mb-2">{{ s.icon }}</div>
              <div class="text-3xl font-extrabold text-blue-600">{{ s.value }}</div>
              <div class="text-xs text-slate-500 mt-1">{{ s.label }}</div>
            </div>
          </div>
        </div>
      </div>

      <!-- ── SECTION 3: พัฒนาหลักสูตร ──────────────────────────────────── -->
      <div v-if="activeSection === 'curriculum'" class="space-y-8">
        <div>
          <p class="text-xs text-blue-600 font-bold uppercase tracking-widest mb-1">Curriculum Development</p>
          <h2 class="text-2xl font-extrabold text-slate-900">กลุ่มงานพัฒนาหลักสูตรการศึกษา</h2>
          <p class="text-slate-500 mt-2 text-sm">ส่งเสริม สนับสนุน และพัฒนาหลักสูตรสถานศึกษาให้สอดคล้องกับหลักสูตรแกนกลางและบริบทท้องถิ่น</p>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div v-for="c in curriculumCards" :key="c.title"
            :class="['rounded-2xl border p-6 hover:shadow-md transition-all', c.color]">
            <div class="text-4xl mb-3">{{ c.icon }}</div>
            <h3 class="font-extrabold text-lg text-slate-800 mb-2">{{ c.title }}</h3>
            <p class="text-sm text-slate-600 mb-4">{{ c.desc }}</p>
            <ul class="space-y-2">
              <li v-for="item in c.items" :key="item" class="flex items-center gap-2 text-sm text-slate-700">
                <span class="w-1.5 h-1.5 bg-blue-500 rounded-full flex-shrink-0"></span>
                <a href="#" class="hover:text-blue-600 hover:underline transition-colors">{{ item }}</a>
                <span class="ml-auto text-[10px] text-slate-400">⬇ ดาวน์โหลด</span>
              </li>
            </ul>
          </div>
        </div>
      </div>

      <!-- ── SECTION 4: นิเทศการศึกษา ─────────────────────────────────── -->
      <div v-if="activeSection === 'supervision'" class="space-y-10">
        <div>
          <p class="text-xs text-blue-600 font-bold uppercase tracking-widest mb-1">Educational Supervision</p>
          <h2 class="text-2xl font-extrabold text-slate-900">กลุ่มงานนิเทศการศึกษา</h2>
        </div>

        <!-- แผนการนิเทศ -->
        <div class="bg-gradient-to-r from-blue-50 to-indigo-50 rounded-3xl p-6 md:p-8 border border-blue-100">
          <div class="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div>
              <h3 class="text-xl font-extrabold text-slate-900 mb-1">📅 แผนการนิเทศ ปีการศึกษา 2567</h3>
              <p class="text-sm text-slate-600">แผนการนิเทศประจำปี/ภาคเรียน สำหรับสถานศึกษาทุกแห่ง</p>
            </div>
            <div class="flex gap-3">
              <a href="#" class="bg-blue-600 text-white px-5 py-2.5 rounded-xl text-sm font-bold hover:bg-blue-700 transition-colors shadow-md">⬇ ดาวน์โหลดแผน</a>
              <a href="#" class="bg-white text-blue-700 border border-blue-200 px-5 py-2.5 rounded-xl text-sm font-bold hover:bg-blue-50 transition-colors">📋 ดูปฏิทิน</a>
            </div>
          </div>
        </div>

        <!-- 8 กลุ่มสาระ -->
        <div>
          <h3 class="text-xl font-extrabold text-slate-900 mb-4">8 กลุ่มสาระการเรียนรู้</h3>
          <div class="grid grid-cols-2 sm:grid-cols-4 gap-3">
            <div v-for="sg in subjectGroups" :key="sg.title"
              :class="['flex flex-col items-center gap-2 p-4 rounded-2xl border cursor-pointer hover:shadow-md hover:-translate-y-0.5 transition-all', sg.color]">
              <span class="text-3xl">{{ sg.icon }}</span>
              <span class="font-bold text-sm text-center leading-snug">{{ sg.title }}</span>
              <span class="text-[10px] opacity-70">คลังสื่อ | แผนสอน</span>
            </div>
          </div>
        </div>

        <!-- Active Learning -->
        <div class="bg-amber-50 border border-amber-200 rounded-3xl p-6">
          <h3 class="text-xl font-extrabold text-slate-900 mb-1">⚡ การจัดการเรียนรู้เชิงรุก (Active Learning)</h3>
          <p class="text-sm text-slate-600 mb-5">ตัวอย่าง Best Practice และแนวทางปฏิบัติสำหรับครู</p>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
            <a href="#" v-for="item in ['สรุปแนวทาง Active Learning', 'Best Practice รางวัลระดับชาติ', 'วิดีโอการสอนตัวอย่าง']" :key="item"
              class="flex items-center gap-2 bg-white border border-amber-100 rounded-xl px-4 py-3 text-sm font-bold text-slate-700 hover:bg-amber-100 hover:text-amber-800 transition-colors">
              <span>📁</span> {{ item }}
            </a>
          </div>
        </div>

        <!-- Coaching & Mentoring -->
        <div>
          <h3 class="text-xl font-extrabold text-slate-900 mb-4">🤝 ระบบ Coaching & Mentoring</h3>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div v-for="ci in coachingItems" :key="ci.title"
              class="bg-white border border-slate-100 rounded-2xl p-5 shadow-sm hover:shadow-md transition-all">
              <div class="text-3xl mb-3">{{ ci.icon }}</div>
              <h4 class="font-bold text-sm text-slate-800 mb-1">{{ ci.title }}</h4>
              <p class="text-xs text-slate-500">{{ ci.desc }}</p>
              <a href="#" class="mt-3 inline-block text-xs font-bold text-blue-600 hover:underline">⬇ ดาวน์โหลด</a>
            </div>
          </div>
        </div>
      </div>

      <!-- ── SECTION 5: วัดและประเมินผล ────────────────────────────────── -->
      <div v-if="activeSection === 'evaluation'" class="space-y-10">
        <div>
          <p class="text-xs text-blue-600 font-bold uppercase tracking-widest mb-1">Educational Evaluation</p>
          <h2 class="text-2xl font-extrabold text-slate-900">กลุ่มงานวัดและประเมินผลการศึกษา</h2>
        </div>

        <!-- การทดสอบระดับชาติ -->
        <div>
          <h3 class="text-xl font-extrabold text-slate-900 mb-4">การทดสอบระดับชาติ</h3>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div v-for="t in nationalTests" :key="t.abbr"
              class="bg-white border border-slate-100 rounded-2xl shadow-sm hover:shadow-md transition-all overflow-hidden">
              <div :class="[t.color, 'p-4 text-white']">
                <div class="flex items-center justify-between">
                  <span class="text-2xl font-extrabold">{{ t.abbr }}</span>
                  <span class="text-2xl">{{ t.icon }}</span>
                </div>
                <p class="text-white/80 text-xs mt-1">{{ t.full }}</p>
                <span class="inline-block bg-white/20 text-white text-[10px] font-bold px-2 py-0.5 rounded-full mt-2">{{ t.grade }}</span>
              </div>
              <div class="p-4">
                <p class="text-xs text-slate-600 leading-relaxed mb-3">{{ t.desc }}</p>
                <div class="flex items-end justify-between">
                  <div>
                    <p class="text-[10px] text-slate-400">คะแนนเฉลี่ยเขตฯ ปี 2566</p>
                    <p class="text-xl font-extrabold text-slate-800">{{ t.score }}</p>
                  </div>
                  <span :class="['text-xs font-bold px-2 py-0.5 rounded-full', t.change.startsWith('+') ? 'bg-emerald-100 text-emerald-700' : 'bg-red-100 text-red-700']">
                    {{ t.change }}
                  </span>
                </div>
                <div class="mt-4 flex gap-2">
                  <a href="#" class="flex-1 text-center text-[10px] font-bold bg-slate-100 text-slate-700 rounded-lg py-1.5 hover:bg-blue-100 hover:text-blue-700 transition-colors">ตารางสอบ</a>
                  <a href="#" class="flex-1 text-center text-[10px] font-bold bg-slate-100 text-slate-700 rounded-lg py-1.5 hover:bg-blue-100 hover:text-blue-700 transition-colors">แนวข้อสอบ</a>
                  <a href="#" class="flex-1 text-center text-[10px] font-bold bg-slate-100 text-slate-700 rounded-lg py-1.5 hover:bg-blue-100 hover:text-blue-700 transition-colors">สรุปผล</a>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- เกณฑ์การวัดผล -->
        <div class="bg-slate-50 rounded-3xl p-6 md:p-8 border border-slate-100">
          <h3 class="text-xl font-extrabold text-slate-900 mb-4">📏 เกณฑ์การวัดและประเมินผล</h3>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div v-for="item in ['ระเบียบการวัดและประเมินผล 2565','เกณฑ์การตัดสินผลการเรียน','การเทียบโอนผลการเรียน']" :key="item"
              class="flex items-center gap-3 bg-white rounded-2xl p-4 border border-slate-100 hover:shadow-sm hover:border-blue-200 transition-all cursor-pointer">
              <span class="text-2xl">📄</span>
              <div>
                <p class="font-bold text-sm text-slate-800">{{ item }}</p>
                <p class="text-[10px] text-blue-600 mt-0.5">⬇ ดาวน์โหลด PDF</p>
              </div>
            </div>
          </div>
        </div>

        <!-- ระบบรายงานผล -->
        <div>
          <h3 class="text-xl font-extrabold text-slate-900 mb-4">🔗 ระบบรายงานผล</h3>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <a v-for="rs in reportSystems" :key="rs.title" :href="rs.href"
              class="flex flex-col items-center p-5 bg-white border border-slate-100 rounded-2xl shadow-sm hover:shadow-md hover:-translate-y-1 transition-all text-center group">
              <span class="text-3xl mb-2">{{ rs.icon }}</span>
              <p class="font-extrabold text-slate-800 group-hover:text-blue-700 transition-colors">{{ rs.title }}</p>
              <p class="text-xs text-slate-500 mt-1 leading-snug">{{ rs.desc }}</p>
              <span class="mt-3 text-[10px] font-bold text-blue-600">เข้าสู่ระบบ →</span>
            </a>
          </div>
        </div>
      </div>

      <!-- ── SECTION 6: ประกันคุณภาพ ───────────────────────────────────── -->
      <div v-if="activeSection === 'quality'" class="space-y-8">
        <div>
          <p class="text-xs text-blue-600 font-bold uppercase tracking-widest mb-1">Quality Assurance</p>
          <h2 class="text-2xl font-extrabold text-slate-900">กลุ่มงานประกันคุณภาพการศึกษา</h2>
          <p class="text-slate-500 mt-2 text-sm">ส่งเสริมและสนับสนุนสถานศึกษาให้มีระบบประกันคุณภาพภายในที่เข้มแข็ง</p>
        </div>
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div v-for="qa in qaCards" :key="qa.title"
            :class="['bg-white rounded-2xl border-l-4 border border-slate-100 p-6 shadow-sm hover:shadow-md transition-all', qa.color]">
            <div class="text-3xl mb-3">{{ qa.icon }}</div>
            <h3 class="font-extrabold text-lg text-slate-800 mb-4">{{ qa.title }}</h3>
            <ul class="space-y-3">
              <li v-for="item in qa.items" :key="item"
                class="flex items-center gap-3 text-sm text-slate-700 bg-slate-50 rounded-xl px-3 py-2 hover:bg-blue-50 hover:text-blue-700 cursor-pointer transition-colors">
                <span class="text-blue-500 flex-shrink-0">📄</span>
                {{ item }}
              </li>
            </ul>
          </div>
        </div>

        <!-- Progress bars mock -->
        <div class="bg-gradient-to-r from-emerald-50 to-teal-50 rounded-3xl p-6 md:p-8 border border-emerald-100">
          <h3 class="text-xl font-extrabold text-slate-900 mb-6">📊 ผลการประเมินคุณภาพ ปีการศึกษา 2566</h3>
          <div class="space-y-4">
            <div v-for="bar in [['ระดับดีเลิศ', 12, 'bg-emerald-500'],['ระดับดีมาก', 35, 'bg-blue-500'],['ระดับดี', 29, 'bg-indigo-400'],['ต้องการการพัฒนา', 8, 'bg-amber-400']]" :key="bar[0]"
              class="flex items-center gap-4">
              <span class="text-sm font-bold text-slate-600 w-36 flex-shrink-0">{{ bar[0] }}</span>
              <div class="flex-1 bg-white rounded-full h-4 border border-slate-100 overflow-hidden">
                <div :class="['h-full rounded-full transition-all duration-700', bar[2]]" :style="`width: ${bar[1]}%`"></div>
              </div>
              <span class="text-sm font-bold text-slate-700 w-16 text-right">{{ bar[1] }} แห่ง</span>
            </div>
          </div>
        </div>
      </div>

      <!-- ── SECTION 7: วิจัย สื่อ เทคโนโลยี ─────────────────────────── -->
      <div v-if="activeSection === 'research'" class="space-y-10">
        <div>
          <p class="text-xs text-blue-600 font-bold uppercase tracking-widest mb-1">Research & Technology</p>
          <h2 class="text-2xl font-extrabold text-slate-900">กลุ่มงานวิจัย สื่อ และเทคโนโลยี</h2>
        </div>

        <!-- คลังวิจัย -->
        <div>
          <h3 class="text-xl font-extrabold text-slate-900 mb-4">📚 คลังวิจัยทางการศึกษา</h3>
          <div class="space-y-3 mb-4">
            <div v-for="r in researchItems" :key="r.title"
              class="flex items-center gap-4 bg-white border border-slate-100 rounded-2xl p-4 shadow-sm hover:shadow-md hover:border-blue-200 transition-all group">
              <div class="text-3xl">{{ r.icon }}</div>
              <div class="flex-1">
                <p class="font-bold text-slate-800 group-hover:text-blue-700 transition-colors">{{ r.title }}</p>
                <p class="text-xs text-slate-500 mt-0.5">โดย {{ r.author }} · {{ r.subject }}</p>
              </div>
              <a href="#" class="text-xs font-bold text-blue-600 hover:underline flex-shrink-0">⬇ ดาวน์โหลด</a>
            </div>
          </div>
          <a href="#" class="inline-flex items-center gap-2 text-sm font-bold text-blue-600 hover:text-blue-800 transition-colors">
            ดูงานวิจัยทั้งหมด →
          </a>
        </div>

        <!-- สื่อ DLTV/DLIT -->
        <div>
          <h3 class="text-xl font-extrabold text-slate-900 mb-4">🖥️ สื่อดิจิทัล (DLTV / DLIT)</h3>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
            <a v-for="ml in mediaLinks" :key="ml.title" :href="ml.href"
              :class="['flex flex-col items-center p-5 rounded-2xl border-2 border-transparent hover:border-current hover:shadow-lg transition-all text-center group', ml.color]">
              <span class="text-3xl mb-2">{{ ml.icon }}</span>
              <p class="font-extrabold text-base">{{ ml.title }}</p>
              <p class="text-xs mt-1 opacity-80 leading-snug">{{ ml.desc }}</p>
            </a>
          </div>
        </div>

        <!-- PA วิทยฐานะ -->
        <div class="bg-violet-50 border border-violet-100 rounded-3xl p-6 md:p-8">
          <h3 class="text-xl font-extrabold text-slate-900 mb-6">🎓 วิทยฐานะ (Performance Agreement)</h3>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <div v-for="(step, i) in paSteps" :key="step.step"
              class="relative bg-white rounded-2xl p-5 border border-violet-100 shadow-sm">
              <div class="w-8 h-8 bg-violet-600 text-white rounded-full flex items-center justify-center font-extrabold text-sm mb-3">{{ step.step }}</div>
              <h4 class="font-bold text-sm text-slate-800 mb-1">{{ step.title }}</h4>
              <p class="text-xs text-slate-500 leading-relaxed">{{ step.desc }}</p>
              <div v-if="i < 3" class="hidden lg:block absolute -right-3 top-1/2 -translate-y-1/2 text-slate-300 text-xl z-10">→</div>
            </div>
          </div>
          <div class="mt-5 flex gap-3">
            <a href="#" class="bg-violet-600 text-white px-5 py-2.5 rounded-xl text-sm font-bold hover:bg-violet-700 transition-colors">คู่มือการทำ PA</a>
            <a href="#" class="bg-white text-violet-700 border border-violet-200 px-5 py-2.5 rounded-xl text-sm font-bold hover:bg-violet-50 transition-colors">ระบบ DPA Online</a>
          </div>
        </div>
      </div>

      <!-- ── SECTION 8: ส่งเสริมการบริหาร ─────────────────────────────── -->
      <div v-if="activeSection === 'secretariat'" class="space-y-10">
        <div>
          <p class="text-xs text-blue-600 font-bold uppercase tracking-widest mb-1">Secretariat & Policy</p>
          <h2 class="text-2xl font-extrabold text-slate-900">กลุ่มงานส่งเสริมพัฒนาระบบการบริหารจัดการ</h2>
        </div>

        <!-- ก.ต.ป.น. -->
        <div>
          <h3 class="text-xl font-extrabold text-slate-900 mb-4">🏛️ คณะกรรมการ ก.ต.ป.น.</h3>
          <div class="bg-slate-50 rounded-3xl border border-slate-100 overflow-hidden">
            <div class="overflow-x-auto">
              <table class="w-full text-sm">
                <thead class="bg-blue-600 text-white">
                  <tr>
                    <th class="px-5 py-3 text-left font-bold">ตำแหน่ง</th>
                    <th class="px-5 py-3 text-left font-bold">ชื่อ-สกุล</th>
                    <th class="px-5 py-3 text-left font-bold">ประเภท</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="(m, i) in ktpnMembers" :key="m.name"
                    :class="['transition-colors', i % 2 === 0 ? 'bg-white' : 'bg-slate-50', 'hover:bg-blue-50']">
                    <td class="px-5 py-3 font-bold text-slate-700">{{ m.role }}</td>
                    <td class="px-5 py-3 text-slate-800">{{ m.name }}</td>
                    <td class="px-5 py-3"><span class="px-2.5 py-1 bg-blue-100 text-blue-700 text-xs font-bold rounded-full">{{ m.type }}</span></td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <!-- โครงการพิเศษ -->
        <div>
          <h3 class="text-xl font-extrabold text-slate-900 mb-4">⭐ โครงการพิเศษ</h3>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div v-for="sp in specialProjects" :key="sp.title"
              :class="['flex items-start gap-4 rounded-2xl border p-5 hover:shadow-md transition-all', sp.color]">
              <span class="text-3xl flex-shrink-0">{{ sp.icon }}</span>
              <div>
                <div class="flex items-center gap-2 mb-1">
                  <h4 class="font-extrabold text-slate-800">{{ sp.title }}</h4>
                  <span class="px-2 py-0.5 bg-white text-slate-600 text-[10px] font-bold rounded-full border">{{ sp.tag }}</span>
                </div>
                <p class="text-sm text-slate-600">{{ sp.desc }}</p>
                <a href="#" class="mt-2 inline-block text-xs font-bold text-blue-600 hover:underline">ดูรายละเอียด →</a>
              </div>
            </div>
          </div>
        </div>

        <!-- รายงานประจำปี -->
        <div class="bg-gradient-to-r from-slate-800 to-slate-900 text-white rounded-3xl p-6 md:p-8">
          <h3 class="text-xl font-extrabold mb-4">📑 รายงานผลการดำเนินงาน (Annual Report)</h3>
          <div class="grid grid-cols-1 sm:grid-cols-3 gap-4">
            <a v-for="y in ['ปีการศึกษา 2566', 'ปีการศึกษา 2565', 'ปีการศึกษา 2564']" :key="y" href="#"
              class="flex items-center gap-3 bg-white/10 backdrop-blur rounded-xl p-4 hover:bg-white/20 transition-colors group">
              <span class="text-3xl">📊</span>
              <div>
                <p class="font-bold text-sm">รายงานประจำปี</p>
                <p class="text-white/70 text-xs">{{ y }}</p>
              </div>
              <span class="ml-auto text-white/50 group-hover:text-white transition-colors">⬇</span>
            </a>
          </div>
        </div>
      </div>

      <!-- ── SECTION 9: บริการและดาวน์โหลด ───────────────────────────── -->
      <div v-if="activeSection === 'services'" class="space-y-10">
        <div>
          <p class="text-xs text-blue-600 font-bold uppercase tracking-widest mb-1">Services & Downloads</p>
          <h2 class="text-2xl font-extrabold text-slate-900">บริการและดาวน์โหลด</h2>
        </div>

        <!-- แบบฟอร์ม -->
        <div>
          <h3 class="text-xl font-extrabold text-slate-900 mb-4">📂 แบบฟอร์มและเอกสาร</h3>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
            <a v-for="f in formDownloads" :key="f.title" href="#"
              class="flex items-center gap-4 bg-white border border-slate-100 rounded-2xl p-4 shadow-sm hover:shadow-md hover:border-blue-200 transition-all group">
              <div class="w-12 h-12 bg-blue-50 rounded-xl flex items-center justify-center text-2xl flex-shrink-0 group-hover:bg-blue-100 transition-colors">
                {{ f.icon }}
              </div>
              <div class="flex-1 min-w-0">
                <p class="font-bold text-sm text-slate-800 group-hover:text-blue-700 transition-colors leading-snug">{{ f.title }}</p>
                <div class="flex items-center gap-2 mt-1">
                  <span class="text-[10px] bg-slate-100 text-slate-500 px-2 py-0.5 rounded font-mono">{{ f.type }}</span>
                  <span class="text-[10px] text-slate-400">{{ f.size }}</span>
                </div>
              </div>
              <span class="text-slate-300 group-hover:text-blue-500 transition-colors text-xl">⬇</span>
            </a>
          </div>
        </div>

        <!-- E-Service -->
        <div>
          <h3 class="text-xl font-extrabold text-slate-900 mb-4">🌐 E-Service</h3>
          <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
            <a v-for="es in eServices" :key="es.title" :href="es.href"
              :class="['flex flex-col items-center p-6 rounded-2xl text-white text-center hover:opacity-90 hover:-translate-y-1 transition-all shadow-lg group', es.color]">
              <span class="text-4xl mb-3">{{ es.icon }}</span>
              <p class="font-extrabold text-lg leading-snug">{{ es.title }}</p>
              <p class="text-white/80 text-xs mt-1">{{ es.desc }}</p>
              <span class="mt-4 bg-white/20 px-4 py-1.5 rounded-full text-xs font-bold group-hover:bg-white/30 transition-colors">เข้าสู่ระบบ →</span>
            </a>
          </div>
        </div>

        <!-- FAQ -->
        <div>
          <h3 class="text-xl font-extrabold text-slate-900 mb-4">❓ คำถามที่พบบ่อย (FAQ)</h3>
          <div class="space-y-3">
            <div v-for="(faq, i) in faqs" :key="i"
              class="bg-white border border-slate-100 rounded-2xl overflow-hidden shadow-sm hover:shadow-md transition-all">
              <button @click="toggleFaq(i)"
                class="w-full flex items-center justify-between px-6 py-4 text-left font-bold text-slate-800 hover:text-blue-700 transition-colors">
                <span>{{ faq.q }}</span>
                <span :class="['transition-transform duration-200 text-slate-400 flex-shrink-0 ml-4', faq.open ? 'rotate-180' : '']">▼</span>
              </button>
              <div v-if="faq.open" class="px-6 pb-5 text-sm text-slate-600 leading-relaxed border-t border-slate-50">
                <p class="pt-4">{{ faq.a }}</p>
              </div>
            </div>
          </div>
        </div>
      </div>

    </div>

    <!-- ═══ FOOTER CONTACT STRIP ══════════════════════════════════════════ -->
    <div class="bg-blue-700 text-white mt-10 py-6">
      <div class="max-w-7xl mx-auto px-4 flex flex-col md:flex-row items-center justify-between gap-3 text-sm">
        <p class="font-bold">กลุ่มนิเทศ ติดตามและประเมินผลการจัดการศึกษา</p>
        <div class="flex gap-6 text-blue-200">
          <span>📞 0X-XXXX-XXXX ต่อ XXX</span>
          <span>📧 nithet@obec.go.th</span>
        </div>
      </div>
    </div>

  </div>
</template>

<style scoped>
.font-sarabun { font-family: 'Sarabun', sans-serif; }
.scrollbar-none::-webkit-scrollbar { display: none; }
.scrollbar-none { -ms-overflow-style: none; scrollbar-width: none; }
</style>
