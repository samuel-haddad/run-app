import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Run App',
  description: 'Seu planejamento de treino de corrida',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body>{children}</body>
    </html>
  )
}
