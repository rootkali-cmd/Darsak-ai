'use client'

import { useEffect, useState } from 'react'
import { motion, AnimatePresence } from 'framer-motion'
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
    <header className="sticky top-0 z-30 px-6 py-3 border-b border-[var(--border)]" style={{ background: 'var(--card-bg)', backdropFilter: 'blur(20px)' }}>
      <div className="flex items-center justify-between gap-4">
        {/* Breadcrumb / HUD */}
        <div className="hud-text flex items-center gap-2">
          <span className="text-[var(--accent)]">●</span>
          <span>SYS.ONLINE</span>
          <span className="text-[rgba(255,255,255,0.2)]">/</span>
          <span>DASHBOARD</span>
        </div>

        {/* Right side */}
        <div className="flex items-center gap-2">
          {/* Search */}
          <motion.div
            className={`relative transition-all duration-300 ${searchFocused ? 'w-64' : 'w-48'}`}
          >
            <Search className={`absolute right-3 top-1/2 -translate-y-1/2 w-4 h-4 transition-colors ${searchFocused ? 'text-[var(--accent-2)]' : 'text-[var(--text-muted)]'}`} />
            <input
              type="text"
              placeholder="SEARCH..."
              onFocus={() => setSearchFocused(true)}
              onBlur={() => setSearchFocused(false)}
              className="brutal-input w-full pr-10 pl-3 py-2 text-xs"
            />
          </motion.div>

          {/* Notifications */}
          <div className="relative">
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={() => {
                setShowNotifications(!showNotifications)
                setShowProfile(false)
              }}
              className="relative p-2 border border-[var(--border)] hover:border-[var(--accent)] transition-colors"
              style={{ background: 'rgba(128,128,128,0.05)' }}
            >
              <Bell className="w-4 h-4 text-[var(--text-muted)]" />
              <span className="absolute -top-1 ltr:-right-1 rtl:-left-1 w-4 h-4 bg-[var(--accent)] text-[8px] flex items-center justify-center text-white font-bold">
                3
              </span>
            </motion.button>

            <AnimatePresence>
              {showNotifications && (
                <motion.div
                  initial={{ opacity: 0, y: -10, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -10, scale: 0.95 }}
                  className="absolute ltr:left-0 rtl:right-0 top-full mt-2 w-72 z-50 brutal-card"
                >
                  <h3 className="font-bold mb-3 hud-text">NOTIFICATIONS</h3>
                  {[
                    { text: 'New student added', time: '5 min ago' },
                    { text: 'Grades updated for Math group', time: '1 hour ago' },
                    { text: 'AI report ready for review', time: '3 hours ago' },
                  ].map((notif, i) => (
                    <motion.div
                      key={i}
                      initial={{ opacity: 0, x: -20 }}
                      animate={{ opacity: 1, x: 0 }}
                      transition={{ delay: i * 0.1 }}
                      className="p-3 border-b border-[rgba(255,255,255,0.05)] hover:bg-[rgba(255,255,255,0.03)] transition-colors cursor-pointer"
                    >
                      <p className="text-xs">{notif.text}</p>
                      <p className="text-[10px] text-[var(--text-muted)] hud-text mt-1">{notif.time}</p>
                    </motion.div>
                  ))}
                </motion.div>
              )}
            </AnimatePresence>
          </div>

          {/* Profile */}
          <div className="relative">
            <motion.button
              whileHover={{ scale: 1.02 }}
              whileTap={{ scale: 0.98 }}
              onClick={() => {
                setShowProfile(!showProfile)
                setShowNotifications(false)
              }}
              className="flex items-center gap-2 px-3 py-2 border border-[rgba(255,255,255,0.1)] hover:border-[var(--accent-2)] transition-colors"
              style={{ background: 'rgba(255,255,255,0.03)' }}
            >
              <div className="w-7 h-7 border border-[var(--accent)] flex items-center justify-center">
                <span className="text-white font-bold text-xs">
                  {userName.charAt(0) || 'M'}
                </span>
              </div>
              <span className="text-xs hud-text hidden md:inline">{userName || 'TEACHER'}</span>
              <ChevronDown className="w-3 h-3 text-[var(--text-muted)]" />
            </motion.button>

            <AnimatePresence>
              {showProfile && (
                <motion.div
                  initial={{ opacity: 0, y: -10, scale: 0.95 }}
                  animate={{ opacity: 1, y: 0, scale: 1 }}
                  exit={{ opacity: 0, y: -10, scale: 0.95 }}
                  className="absolute ltr:left-0 rtl:right-0 top-full mt-2 w-48 z-50 brutal-card"
                >
                  <div className="p-3 border-b border-[var(--border)] mb-1">
                    <p className="text-sm font-bold">{userName || 'TEACHER'}</p>
                    <p className="text-[10px] text-[var(--text-muted)] hud-text">TEACHER</p>
                  </div>
                  <button className="w-full text-start px-3 py-2 hover:bg-[rgba(128,128,128,0.05)] transition-colors text-xs hud-text flex items-center gap-2">
                    <User className="w-3 h-3" />
                    PROFILE
                  </button>
                  <button className="w-full text-start px-3 py-2 hover:bg-[rgba(255,0,60,0.08)] transition-colors text-xs hud-text flex items-center gap-2 text-[var(--accent)]">
                    <LogOut className="w-3 h-3" />
                    LOGOUT
                  </button>
                </motion.div>
              )}
            </AnimatePresence>
          </div>
        </div>
      </div>
    </header>
  )
}
