'use client'

import { useEffect, useState } from 'react'
import { Bell, Search, ChevronDown, User, LogOut } from 'lucide-react'
import { authApi } from '@/lib/api'

export function Header() {
  const [userName, setUserName] = useState('')
  const [searchFocused, setSearchFocused] = useState(false)
  const [showNotifications, setShowNotifications] = useState(false)
  const [showProfile, setShowProfile] = useState(false)

  useEffect(() => {
    authApi.getMe().then((res) => {
      setUserName(res.data.full_name)
    }).catch(() => {})
  }, [])

  return (
    <header className="sticky top-0 z-30 px-6 py-3 border-b border-[var(--card-border)]" style={{ background: 'var(--bg-secondary)' }}>
      <div className="flex items-center justify-between gap-4">
        <div className="text-xs text-[var(--text-muted)]">لوحة التحكم</div>

        <div className="flex items-center gap-2">
          <div className={`relative transition-all duration-300 ${searchFocused ? 'w-40 md:w-56' : 'w-28 md:w-40'}`}>
            <Search className={`absolute right-2.5 top-1/2 -translate-y-1/2 w-3.5 h-3.5 ${searchFocused ? 'text-[var(--accent)]' : 'text-[var(--text-muted)]'}`} />
            <input
              type="text"
              placeholder="بحث..."
              onFocus={() => setSearchFocused(true)}
              onBlur={() => setSearchFocused(false)}
              className="input !py-1.5 pr-8 pl-2 text-xs"
            />
          </div>

          <div className="relative">
            <button
              onClick={() => { setShowNotifications(!showNotifications); setShowProfile(false) }}
              className="relative p-2 border border-[var(--card-border)] hover:border-[var(--accent)] transition-colors"
            >
              <Bell size={16} className="text-[var(--text-muted)]" />
              <span className="absolute -top-1 -left-1 w-3.5 h-3.5 bg-[var(--accent)] text-[7px] flex items-center justify-center text-white font-bold">
                3
              </span>
            </button>

            {showNotifications && (
              <div className="absolute left-0 top-full mt-2 w-64 z-50 card p-3">
                <h3 className="text-xs font-bold mb-3 text-[var(--text-muted)]">الإشعارات</h3>
                {[
                  { text: 'تم إضافة طالب جديد', time: 'منذ 5 دقائق' },
                  { text: 'تم تحديث درجات مجموعة الرياضيات', time: 'منذ ساعة' },
                  { text: 'تقرير AI جاهز للمراجعة', time: 'منذ 3 ساعات' },
                ].map((notif, i) => (
                  <div key={i} className="p-2 border-b border-[var(--card-border)] last:border-b-0 hover:bg-[rgba(0,0,0,0.02)] transition-colors cursor-pointer">
                    <p className="text-xs">{notif.text}</p>
                    <p className="text-[10px] text-[var(--text-muted)] mt-0.5">{notif.time}</p>
                  </div>
                ))}
              </div>
            )}
          </div>

          <div className="relative">
            <button
              onClick={() => { setShowProfile(!showProfile); setShowNotifications(false) }}
              className="flex items-center gap-2 px-3 py-1.5 border border-[var(--card-border)] hover:border-[var(--accent)] transition-colors"
            >
              <div className="w-6 h-6 bg-[var(--accent)] flex items-center justify-center">
                <span className="text-white text-xs font-bold">
                  {userName?.charAt(0) || 'M'}
                </span>
              </div>
              <span className="text-xs hidden md:inline text-[var(--text-muted)]">{userName || 'المعلم'}</span>
              <ChevronDown size={12} className="text-[var(--text-muted)]" />
            </button>

            {showProfile && (
              <div className="absolute left-0 top-full mt-2 w-48 z-50 card p-2">
                <div className="p-2 border-b border-[var(--card-border)] mb-1">
                  <p className="text-sm font-bold">{userName || 'المعلم'}</p>
                  <p className="text-[10px] text-[var(--text-muted)]">معلم</p>
                </div>
                <button className="w-full text-right px-2 py-1.5 text-xs hover:bg-[rgba(0,0,0,0.03)] transition-colors flex items-center gap-2">
                  <User size={12} />
                  الملف الشخصي
                </button>
                <button className="w-full text-right px-2 py-1.5 text-xs text-[var(--accent)] hover:bg-[rgba(220,38,38,0.06)] transition-colors flex items-center gap-2">
                  <LogOut size={12} />
                  تسجيل الخروج
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  )
}
