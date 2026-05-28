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
  CreditCard,
  BarChart3,
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
  { href: '/admin/analytics', label: 'التحليلات', icon: BarChart3 },
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
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="lg:hidden fixed top-3 right-3 z-50 p-2 border border-[var(--card-border)] bg-[var(--bg)]"
      >
        {isOpen ? <X size={20} /> : <Menu size={20} />}
      </button>

      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="lg:hidden fixed inset-0 bg-black/60 z-40"
            onClick={() => setIsOpen(false)}
          />
        )}
      </AnimatePresence>

      <aside
        className={`fixed top-0 right-0 h-full w-64 z-50 transform transition-transform duration-300 border-l border-[var(--card-border)] bg-[var(--bg)] ${
          isOpen ? 'translate-x-0' : 'translate-x-full lg:translate-x-0'
        }`}
      >
        <div className="flex flex-col h-full">
          <div className="p-5 border-b border-[var(--card-border)]">
            <Link href="/dashboard" className="flex items-center gap-2.5">
              <span               className="text-[var(--accent)] font-black text-lg" style={{ fontFamily: "'JetBrains Mono', monospace" }}>
                DARSAK AI
              </span>
            </Link>
          </div>

          <nav className="flex-1 p-3 space-y-0.5 overflow-y-auto">
            {navItems.map((item) => {
              const isActive = pathname === item.href
              const Icon = item.icon
              return (
                <Link
                  key={item.href}
                  href={item.href}
                  onClick={() => setIsOpen(false)}
                  className={`flex items-center gap-3 px-3 py-2.5 text-sm rounded-none transition-colors ${
                    isActive
                      ? 'bg-[rgba(220,38,38,0.08)] text-[var(--text)] font-medium border-r-2 border-[var(--accent)]'
                      : 'text-[var(--text-muted)] hover:text-[var(--text)] hover:bg-[rgba(0,0,0,0.02)]'
                  }`}
                >
                  <Icon size={18} />
                  <span>{item.label}</span>
                </Link>
              )
            })}
          </nav>

          <div className="p-3 border-t border-[var(--card-border)] space-y-0.5">
            <Link
              href="/dashboard/assistants"
              className="flex items-center gap-3 px-3 py-2.5 text-sm text-[var(--text-muted)] hover:text-[var(--text)] hover:bg-[rgba(0,0,0,0.02)] transition-colors rounded-none"
            >
              <UserCog size={18} />
              <span>المساعدون</span>
            </Link>
            <button
              onClick={handleLogout}
              className="w-full flex items-center gap-3 px-3 py-2.5 text-sm text-[var(--accent)] hover:bg-[rgba(220,38,38,0.06)] transition-colors rounded-none"
            >
              <LogOut size={18} />
              <span>تسجيل الخروج</span>
            </button>
          </div>
        </div>
      </aside>
    </>
  )
}
