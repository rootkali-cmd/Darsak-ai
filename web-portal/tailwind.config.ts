import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        bg: {
          primary: '#030303',
          secondary: '#0a0a0a',
        },
        primary: {
          DEFAULT: '#ff003c',
          glow: 'rgba(255, 0, 60, 0.5)',
          light: '#ff3366',
          dark: '#cc0030',
        },
        secondary: {
          DEFAULT: '#00f3ff',
          glow: 'rgba(0, 243, 255, 0.5)',
        },
        accent: {
          cyan: '#00f3ff',
          orange: '#F59E0B',
          green: '#10B981',
        },
        text: {
          primary: '#e0e0e0',
          secondary: '#94A3B8',
          muted: '#64748B',
        },
        border: 'rgba(255, 255, 255, 0.1)',
        success: '#10B981',
        warning: '#F59E0B',
        danger: '#EF4444',
      },
      fontFamily: {
        sans: ['Tajawal', 'system-ui', 'sans-serif'],
      },
      backgroundImage: {
        'neon-gradient': 'linear-gradient(135deg, #ff003c 0%, #00f3ff 100%)',
      },
      boxShadow: {
        'neon': '0 0 20px rgba(255, 0, 60, 0.4), 0 0 40px rgba(255, 0, 60, 0.2)',
        'neon-hover': '0 0 30px rgba(255, 0, 60, 0.6), 0 0 60px rgba(255, 0, 60, 0.3)',
      },
      keyframes: {
        spotlight: {
          '0%': { opacity: '0', transform: 'translate(-72%, -62%) scale(0.5)' },
          '100%': { opacity: '1', transform: 'translate(-50%, -40%) scale(1)' },
        },
      },
      animation: {
        spotlight: 'spotlight 2s ease .75s 1 forwards',
      },
    },
  },
  plugins: [],
}
export default config
