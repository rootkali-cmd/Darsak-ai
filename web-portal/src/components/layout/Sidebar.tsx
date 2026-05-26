'use client'

import { useState } from 'react'
import Link from 'next/link'
import { usePathname } from 'next/navigation'
import { motion, AnimatePresence } from 'framer-motion'
import {
  LayoutDashboard,
  Users,
  BookOpen,
  CalendarCheck,
  GraduationCap,
  Receipt,
  QrCode,
  Download,
  Settings,
  LogOut,
  Menu,
  X,
  UserCog,
  Sparkles,
  CreditCard,
  BarChart2,
} from 'lucide-react'
import { auth } from '@/lib/auth'

const navItems = [
  { href: '/dashboard', label: 'لوحة التحكم', icon: LayoutDashboard },
  { href: '/dashboard/students', label: 'الطلاب', icon: Users },
  { href: '/dashboard/groups', label: 'المجموعات', icon: BookOpen },
  { href: '/dashboard/attendance', label: 'الحضور', icon: CalendarCheck },
  { href: '/dashboard/grades', label: 'الدرجات', icon: GraduationCap },
  { href: '/dashboard/invoices', label: 'الفواتير', icon: Receipt },
  { href: '/dashboard/qr', label: 'QR Code', icon: QrCode },
  { href: '/dashboard/downloads', label: 'التطبيقات', icon: Download },
  { href: '/dashboard/subscription', label: 'الاشتراكات', icon: CreditCard },
  { href: '/dashboard/settings', label: 'الإعدادات', icon: Settings },
  { href: '/admin/analytics', label: 'التحليلات', icon: BarChart2 },
]

export function Sidebar() {
  const pathname = usePathname()
  const [isOpen, setIsOpen] = useState(false)

const handleLogout = () => {
  if (confirm('هل أنت متأكد من تسجيل الخروج؟')) {
    auth.clearTokens()
    window.location.href = '/login'
  }
}

  return (
    <>
      {/* Mobile Menu Button */}
      <motion.button
        whileHover={{ scale: 1.1 }}
        whileTap={{ scale: 0.9 }}
        onClick={() => setIsOpen(!isOpen)}
        className="lg:hidden fixed top-4 right-4 z-50 p-3 brutal-card text-white"
      >
        {isOpen ? <X className="w-6 h-6" /> : <Menu className="w-6 h-6" />}
      </motion.button>

      {/* Overlay */}
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="lg:hidden fixed inset-0 bg-black/80 z-40"
            onClick={() => setIsOpen(false)}
          />
        )}
      </AnimatePresence>

      {/* Sidebar */}
      <motion.aside
        className={`fixed top-0 right-0 h-full w-72 z-50 transform transition-transform duration-500 lg:translate-x-0 border-l border-[var(--border)] ${
          isOpen ? 'translate-x-0' : 'translate-x-full lg:translate-x-0'
        }`}
        style={{ background: 'var(--card-bg)', backdropFilter: 'blur(20px)' }}
      >
        <div className="flex flex-col h-full">
          {/* Logo */}
          <div className="p-6 border-b border-[var(--border)] relative">
            <div className="absolute top-0 left-0 w-4 h-4 border-t border-l border-[var(--accent)]" />
            <div className="absolute top-0 right-0 w-4 h-4 border-t border-r border-[var(--accent-2)]" />
            <Link href="/dashboard" className="flex items-center gap-3 group">
              <motion.div
                whileHover={{ rotate: 180, scale: 1.1 }}
                transition={{ duration: 0.5 }}
                className="w-10 h-10 flex items-center justify-center border border-[var(--accent)]"
              >
                <Sparkles className="w-5 h-5 text-[var(--accent)]" />
              </motion.div>
              <div>
                <h1 className="font-bold text-lg text-white" style={{ fontFamily: 'var(--font-display)' }}>
                  DARSAK AI
                </h1>
                <p className="text-xs text-[var(--accent-2)] hud-text">SYS.ONLINE</p>
              </div>
            </Link>
          </div>

          {/* Navigation */}
          <nav className="flex-1 p-4 space-y-1 overflow-y-auto">
            {navItems.map((item, index) => {
              const isActive = pathname === item.href
              const Icon = item.icon

              return (
                <motion.div
                  key={item.href}
                  initial={{ opacity: 0, x: 30 }}
                  animate={{ opacity: 1, x: 0 }}
                  transition={{ delay: index * 0.05 }}
                >
                  <Link
                    href={item.href}
                    onClick={() => setIsOpen(false)}
                    className={`relative flex items-center gap-3 px-4 py-3 transition-all duration-300 group ${
                      isActive
                        ? 'border border-[var(--accent)] bg-[rgba(255,0,60,0.08)]'
                        : 'border border-transparent hover:border-[rgba(255,255,255,0.1)] hover:bg-[rgba(255,255,255,0.03)]'
                    }`}
                  >
                    <Icon className={`w-5 h-5 ${isActive ? 'text-[var(--accent)]' : 'text-[var(--text-muted)] group-hover:text-[var(--text)]'}`} />
                    <span className={`font-medium text-sm ${isActive ? 'text-white' : 'text-[var(--text-muted)]'}`}>
                      {item.label}
                    </span>
                    {isActive && (
                      <span className="ltr:ml-auto rtl:mr-auto text-[var(--accent-2)] hud-text">ACTV</span>
                    )}
                  </Link>
                </motion.div>
              )
            })}
          </nav>

          {/* User & Logout */}
          <div className="p-4 border-t border-[var(--border)] space-y-2">
            <Link
              href="/dashboard/assistants"
              className="flex items-center gap-3 px-4 py-3 border border-transparent hover:border-[rgba(255,255,255,0.1)] hover:bg-[rgba(255,255,255,0.03)] transition-all duration-300"
            >
              <UserCog className="w-5 h-5 text-[var(--text-muted)]" />
              <span className="font-medium text-sm text-[var(--text-muted)]">المساعدون</span>
            </Link>
            <motion.button
              whileHover={{ scale: 1.02, x: -5 }}
              whileTap={{ scale: 0.98 }}
              onClick={handleLogout}
              className="w-full flex items-center gap-3 px-4 py-3 border border-transparent hover:border-[var(--accent)] hover:bg-[rgba(255,0,60,0.08)] transition-all duration-300"
            >
              <LogOut className="w-5 h-5 text-[var(--accent)]" />
              <span className="font-medium text-sm text-[var(--accent)]">تسجيل الخروج</span>
            </motion.button>
          </div>
        </div>
      </motion.aside>
    </>
  )
}
