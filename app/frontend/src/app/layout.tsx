import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'
import { AuthProvider } from '@/contexts/AuthContext'
import '@/lib/amplify-config'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: '新潟市介護保険事業所システム',
  description: '新潟市介護保険事業所向け申請管理システム',
}

/**
 * ルートレイアウト
 * 目的: アプリケーション全体のレイアウトと認証プロバイダーを提供
 * 影響: すべてのページ
 * 前提: AuthProvider で認証状態を管理
 */
export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="ja">
      <body className={inter.className}>
        <AuthProvider>
          {children}
        </AuthProvider>
      </body>
    </html>
  )
}
