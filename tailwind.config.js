/** @type {import('tailwindcss').Config} */
export default {
  darkMode: 'class',
  content: [
    "./index.html",
    "./src/**/*.{vue,js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Sarabun', 'sans-serif'],
      },
      // ค่ากลางของธีมกระจก — ใช้ตอนเขียน inline ตรงจุดที่ไม่คุ้มทำเป็น class
      // (พื้นผิวหลักใช้ .glass-card / .glass-nav / .glass-panel / .glass-tile ใน style.css)
      backdropBlur: {
        glass: '20px',
      },
      boxShadow: {
        glass:    '0 8px 32px rgba(15,23,42,0.08), inset 0 1px 0 rgba(255,255,255,0.9)',
        'glass-lg': '0 16px 44px rgba(15,23,42,0.12), inset 0 1px 0 #fff',
        'glass-xl': '0 24px 64px rgba(15,23,42,0.16), inset 0 1px 0 #fff',
      },
    },
  },
  plugins: [],
}
