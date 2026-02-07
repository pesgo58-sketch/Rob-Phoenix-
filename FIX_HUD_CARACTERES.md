# Correção de Pontos de Interrogação no HUD

## Problema
O HUD (interface visual) estava exibindo pontos de interrogação (?) no lugar de alguns caracteres especiais.

## Causa
O código usava caracteres Unicode que não são suportados pela fonte Arial no MetaTrader 5:
- `═` - Linha dupla horizontal (box drawing)
- `░` - Bloco de sombra leve (light shade)
- `▓` - Bloco de sombra escura (dark shade)
- `●` - Bullet (círculo preenchido)
- `▲` - Triângulo para cima
- `▼` - Triângulo para baixo
- `🛡️` - Emoji de escudo

## Solução
Substituição de todos os caracteres Unicode por equivalentes ASCII universalmente suportados:

### Mudanças Implementadas

1. **Divisor do HUD** (Linha 3103)
   - **Antes**: `══════════════════════════════════════════`
   - **Depois**: `==========================================`

2. **Barra de Progresso Inicial** (Linha 3133)
   - **Antes**: `[░░░░░░░░░░░░░░░░░░░░] (0.0%)`
   - **Depois**: `[--------------------] (0.0%)`

3. **Ícone de Direção Neutro** (Linha 3178)
   - **Antes**: `Direção: ● NEUTRO`
   - **Depois**: `Direção: O NEUTRO`

4. **Barras de Progresso** (Linhas 3324-3344)
   - **Antes**: Usava `░` para vazio e `▓` para preenchido
   - **Depois**: Usa `-` para vazio e `#` para preenchido
   - **Exemplo**: `[##########----------]` representa 50% de progresso

5. **Ícones de Direção** (Linhas 3357-3359)
   - **Antes**: `▲` (BUY), `▼` (SELL), `●` (NEUTRO)
   - **Depois**: `^` (BUY), `v` (SELL), `O` (NEUTRO)

6. **Título do HUD** (Linha 3420)
   - **Antes**: `🛡️ PHOENIX TRADER v307F SUPER CORRIGIDO`
   - **Depois**: `PHOENIX TRADER v307F SUPER CORRIGIDO`

## Resultado
O HUD agora exibe todos os caracteres corretamente usando apenas caracteres ASCII padrão que são suportados por todas as fontes no MetaTrader 5.

## Teste
Para verificar a correção:
1. Compilar o EA no MetaEditor (F7)
2. Anexar ao gráfico
3. Verificar que o HUD exibe sem pontos de interrogação
4. Verificar que a barra de progresso usa `#` e `-`
5. Verificar que os ícones de direção usam `^`, `v`, `O`

## Arquivos Modificados
- `Phoenix_Trader_v307_FIXED_CORRIGIDO.mq5`

## Compatibilidade
✅ 100% compatível com ASCII
✅ Funciona em qualquer fonte
✅ Sem problemas de encoding
✅ Visual limpo e profissional
