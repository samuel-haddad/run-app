import { createClient } from '@/lib/supabase/server'
import { notFound } from 'next/navigation'
import { BottomNav } from '@/components/BottomNav'
import { TreinoClient } from './TreinoClient'
import { parseMarkdown } from '@/lib/parsers/markdown'

export default async function TreinoPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  const { data: treino } = await supabase
    .from('treinos')
    .select(`*, ciclos ( id, nome, detalhamento_md ), registros ( id, anotacao, concluido_em )`)
    .eq('id', id)
    .eq('user_id', user!.id)
    .single()

  if (!treino) notFound()

  const detalhamento = treino.ciclos?.detalhamento_md
    ? parseMarkdown(treino.ciclos.detalhamento_md)
    : null

  const registroExistente = treino.registros?.[0] ?? null

  return (
    <>
      <TreinoClient
        treino={treino}
        detalhamento={detalhamento}
        registroExistente={registroExistente}
      />
      <BottomNav />
    </>
  )
}
