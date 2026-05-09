import { createClient } from '@/lib/supabase/server'
import { BottomNav } from '@/components/BottomNav'
import { PlanejamentoClient } from './PlanejamentoClient'

export default async function PlanejamentoPage() {
  const supabase = await createClient()

  const { data: { user } } = await supabase.auth.getUser()

  // Busca todos os treinos com join dos registros
  const { data: treinos } = await supabase
    .from('treinos')
    .select(`
      *,
      ciclos ( id, nome ),
      registros ( id, concluido_em )
    `)
    .eq('user_id', user!.id)
    .order('data_treino', { ascending: true })

  return (
    <>
      <PlanejamentoClient treinos={treinos ?? []} />
      <BottomNav />
    </>
  )
}
