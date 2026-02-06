# 🚀 Phoenix Trader v3.08 - Guia para Contas Pequenas ($100)

## 📋 Índice
1. [Novidades da Versão 3.08](#novidades)
2. [Configuração Recomendada](#configuração-recomendada)
3. [Sistema de Risk Overlay](#sistema-de-risk-overlay)
4. [Circuit Breakers](#circuit-breakers)
5. [Exemplos Práticos](#exemplos-práticos)
6. [Troubleshooting](#troubleshooting)

---

## 🎯 Novidades da Versão 3.08 {#novidades}

### ✨ Risk Overlay por Qualidade de Estado
O EA agora ajusta automaticamente o tamanho da posição baseado na qualidade do estado de mercado:

- **💎 Elite** (qualidade > 0.8): Multiplicador **2.0x** - Aposta máxima em setups excelentes
- **🚀 Good** (qualidade 0.3-0.8): Multiplicador **1.5x** - Aposta elevada em bons setups
- **📊 Neutral** (qualidade 0.0-0.3): Multiplicador **1.0x** - Aposta normal
- **⚠️ Bad** (qualidade < 0.0): Multiplicador **0.5x** - Aposta reduzida em setups ruins

### 🚨 Circuit Breakers Automáticos
Proteção contra perdas excessivas com limites diários e semanais:

- **Circuit Breaker Diário**: Para negociação se perder mais que o limite configurado por dia
- **Circuit Breaker Semanal**: Para negociação se perder mais que o limite configurado por semana
- **Reset Automático**: Os limites resetam automaticamente no novo período

### 💰 Gestão de Risco Baseada em Percentual
Agora você pode configurar o risco por trade como percentual do saldo:

- **Cálculo Automático**: EA calcula o lote baseado em % do saldo e distância do SL
- **Adaptável**: Se o saldo cresce, o lote aumenta proporcionalmente
- **Seguro**: Sempre respeita os limites mínimos e máximos do símbolo

---

## ⚙️ Configuração Recomendada para Conta $100 {#configuração-recomendada}

### 1️⃣ Parâmetros Básicos de Negociação

```
LotSize = 0.01                    // Lote base (mínimo para maioria dos brokers)
MagicNumber = 27101               // Não alterar
MinMinutesBetweenTrades = 3       // Mínimo 3 minutos entre trades
MaxTradesPerDay = 30              // Máximo de trades por dia
ConsecutiveLossLimit = 15         // Parar após 15 perdas consecutivas
```

### 2️⃣ Gestão de Risco Baseada em %

```
UseAccountRiskPercent = true              // ✅ HABILITAR
AccountRiskPerTradePercent = 1.0          // 1% do saldo por trade ($1 em conta de $100)
MaxAllowedLot = 0.1                       // Limite máximo de lote (proteção)
```

**💡 Explicação:**
- Com $100 e risco de 1%, você arrisca $1 por trade
- Se o SL é 350 pips, o EA calcula automaticamente o lote apropriado
- Conforme o saldo cresce, o lote aumenta proporcionalmente

### 3️⃣ Risk Overlay por Qualidade

```
EnableStateQualityRiskOverlay = true      // ✅ HABILITAR
QualityMultiplier_Elite = 2.0             // Dobrar lote em setups Elite
QualityMultiplier_Good = 1.5              // 50% mais em setups Good
QualityMultiplier_Neutral = 1.0           // Lote normal em setups Neutral
QualityMultiplier_Bad = 0.5               // Metade do lote em setups Bad
```

**💡 Explicação:**
- O EA analisa a qualidade do estado de mercado
- Aumenta automaticamente a aposta em setups de alta qualidade
- Reduz a aposta (ou cancela) em setups de baixa qualidade

### 4️⃣ Circuit Breakers (Proteção)

```
// Proteção Diária
EnableDailyCircuitBreaker = true          // ✅ HABILITAR
DailyMaxLossPercent = 5.0                 // Parar se perder 5% no dia ($5 em $100)
DailyMaxLossCurrency = 5.0                // Ou parar se perder $5 no dia

// Proteção Semanal
EnableWeeklyCircuitBreaker = true         // ✅ HABILITAR
WeeklyMaxLossPercent = 10.0               // Parar se perder 10% na semana ($10 em $100)
WeeklyMaxLossCurrency = 10.0              // Ou parar se perder $10 na semana
```

**💡 Explicação:**
- Se você perder $5 em um dia, o EA para de abrir novas posições até o próximo dia
- Se você perder $10 em uma semana, o EA para até a próxima semana
- Isso protege seu capital contra sequências de perdas devastadoras

### 5️⃣ Stop Loss e Take Profit

```
UseFixedSL = true                         // ✅ HABILITAR
FixedSL_Points = 35000                    // 350 pips de SL

UseFixedTP = true                         // ✅ HABILITAR
FixedTP_Points = 70000                    // 700 pips de TP (R:R de 1:2)
```

**💡 Explicação:**
- SL de 350 pips garante que o lote não seja muito grande
- TP de 700 pips dá ratio risco:recompensa de 1:2
- Ajuste conforme o par que você negocia (forex vs índices)

### 6️⃣ Smart Lot (Sistema Tradicional)

```
EnableSmartLot = false                    // ❌ DESABILITAR (usar Risk Overlay)
```

**💡 Explicação:**
- Desabilite o SmartLot tradicional se estiver usando Risk Overlay
- Evita conflito entre os dois sistemas
- Se preferir o SmartLot tradicional, desabilite o Risk Overlay

---

## 📊 Sistema de Risk Overlay {#sistema-de-risk-overlay}

### Como Funciona

O Risk Overlay funciona em 3 etapas:

#### Etapa 1: Calcular Lote Base
```
Lote Base = (Saldo × % Risco) ÷ (SL em $ × Tamanho do Lote)
```

**Exemplo com $100:**
- Saldo: $100
- Risco: 1% = $1
- SL: 350 pips
- Lote calculado: ~0.01 (depende do símbolo)

#### Etapa 2: Aplicar Multiplicador de Qualidade
```
Lote Ajustado = Lote Base × Multiplicador de Qualidade
```

**Exemplo com Estado Elite:**
- Lote Base: 0.01
- Qualidade: 0.9 (Elite)
- Multiplicador: 2.0x
- Lote Final: 0.02

#### Etapa 3: Validar Limites
```
Se Lote Final > MaxAllowedLot → Usar MaxAllowedLot
Se Lote Final < SYMBOL_VOLUME_MIN → Usar SYMBOL_VOLUME_MIN
```

### Categorias de Qualidade

| Categoria | Score | Multiplicador | Descrição |
|-----------|-------|---------------|-----------|
| 💎 **Elite** | > 0.8 | 2.0x | Setup excelente, alta confiança, win rate > 70% |
| 🚀 **Good** | 0.3 - 0.8 | 1.5x | Bom setup, confiança moderada, win rate > 55% |
| 📊 **Neutral** | 0.0 - 0.3 | 1.0x | Setup neutro, sem viés claro |
| ⚠️ **Bad** | < 0.0 | 0.5x | Setup ruim, baixa confiança, win rate < 45% |
| 🚫 **Muito Bad** | < -0.5 | - | Trade cancelado automaticamente |

### Logs de Exemplo

Quando o EA calcula o lote, você verá logs assim no Journal:

```
💰 LOTE BASE (% RISCO): 0.01 (1.00% de risco)
🎯 RISK OVERLAY: Estado=245 | Qualidade=0.850 | Categoria=💎 ELITE | Multiplicador=2.00x | LoteBase=0.01 → LoteAjustado=0.02
📊 LOT DECISION SUMMARY: 💎 ELITE → BaseLot=0.01 | AfterOverlay=0.02 | SmartMult=1.00 | FinalLot=0.02 | Quality=0.850 | PyramidLevel=0
```

---

## 🚨 Circuit Breakers {#circuit-breakers}

### Como Funcionam

Os circuit breakers monitoram seu P&L (lucro/prejuízo) em tempo real e bloqueiam novas entradas se os limites forem atingidos.

### Verificação Diária

1. **Início do Dia**: O EA registra seu saldo inicial
2. **Durante o Dia**: Cada trade fechado atualiza o P&L acumulado do dia
3. **Verificação**: Antes de cada nova entrada, verifica se o limite foi atingido
4. **Reset**: Às 00:00, o P&L diário é resetado e o circuit breaker é desativado

### Verificação Semanal

Funciona da mesma forma que a diária, mas reseta no início de cada semana (segunda-feira).

### Logs de Circuit Breaker

#### Quando Ativado:
```
🚨🚨🚨 CIRCUIT BREAKER DIÁRIO ATIVADO 🚨🚨🚨
   📉 Perda diária: -5.20% (limite: 5.00%)
   💰 P&L do dia: $-5.20
   ⛔ NOVAS ENTRADAS BLOQUEADAS ATÉ AMANHÃ
```

#### Quando Trade é Bloqueado:
```
🚨🚨🚨 CIRCUIT BREAKER ATIVO - Trade cancelado por proteção de risco
🚨 Circuit Breaker Diário Ativo
```

#### Tracking em Cada Trade:
```
💰 CIRCUIT BREAKER UPDATE:
   📊 P&L deste trade: $-1.50
   📅 P&L diário acumulado: $-3.50
   📆 P&L semanal acumulado: $-5.20
```

### Configurações Agressivas vs Conservadoras

#### 🛡️ **Conservador** (Recomendado para Iniciantes)
```
DailyMaxLossPercent = 3.0      // Parar com 3% de perda
WeeklyMaxLossPercent = 7.0     // Parar com 7% de perda semanal
```

#### ⚖️ **Balanceado** (Padrão)
```
DailyMaxLossPercent = 5.0      // Parar com 5% de perda
WeeklyMaxLossPercent = 10.0    // Parar com 10% de perda semanal
```

#### ⚡ **Agressivo** (Apenas para Traders Experientes)
```
DailyMaxLossPercent = 10.0     // Parar com 10% de perda
WeeklyMaxLossPercent = 20.0    // Parar com 20% de perda semanal
```

---

## 💡 Exemplos Práticos {#exemplos-práticos}

### Exemplo 1: Primeiro Trade do Dia

**Situação:**
- Conta: $100
- Estado de Mercado: Qualidade 0.4 (Good)
- SL: 350 pips

**Cálculo:**
1. Lote base (1% de $100): 0.01
2. Multiplicador Good (1.5x): 0.01 × 1.5 = 0.015
3. Arredondado para 0.01 (step do símbolo)
4. Trade executado com 0.01 lote

**Logs:**
```
💰 LOTE BASE (% RISCO): 0.01 (1.00% de risco)
🎯 RISK OVERLAY: Estado=123 | Qualidade=0.400 | Categoria=🚀 GOOD | Multiplicador=1.50x | LoteBase=0.01 → LoteAjustado=0.01
```

### Exemplo 2: Setup Elite

**Situação:**
- Conta: $150 (já ganhou $50)
- Estado de Mercado: Qualidade 0.95 (Elite)
- SL: 350 pips

**Cálculo:**
1. Lote base (1% de $150): ~0.015
2. Multiplicador Elite (2.0x): 0.015 × 2.0 = 0.03
3. Trade executado com 0.03 lote

**Resultado:**
- Se ganhar 700 pips: ~$21 de lucro
- Se perder 350 pips: ~$10.50 de perda (ainda dentro do limite diário)

### Exemplo 3: Circuit Breaker em Ação

**Situação:**
- Conta inicial do dia: $100
- Limite diário: 5% ($5)

**Trades do Dia:**
1. Trade 1: -$2.00 (P&L diário: -$2.00)
2. Trade 2: -$1.50 (P&L diário: -$3.50)
3. Trade 3: -$1.80 (P&L diário: -$5.30) ← **Circuit Breaker Ativado!**
4. Sinal de Trade 4: **BLOQUEADO** ❌

**Logs:**
```
Após Trade 3:
💰 CIRCUIT BREAKER UPDATE:
   📊 P&L deste trade: $-1.80
   📅 P&L diário acumulado: $-5.30
🚨🚨🚨 CIRCUIT BREAKER DIÁRIO ATIVADO 🚨🚨🚨

Tentativa de Trade 4:
🚨🚨🚨 CIRCUIT BREAKER ATIVO - Trade cancelado por proteção de risco
```

### Exemplo 4: Estado Bad

**Situação:**
- Conta: $100
- Estado de Mercado: Qualidade -0.2 (Bad)
- SL: 350 pips

**Cálculo:**
1. Lote base (1% de $100): 0.01
2. Multiplicador Bad (0.5x): 0.01 × 0.5 = 0.005
3. Arredondado para 0.01 (mínimo)
4. Trade executado com lote reduzido

**Nota:** Se a qualidade fosse < -0.5, o trade seria cancelado automaticamente.

---

## 🔧 Troubleshooting {#troubleshooting}

### Problema: Lotes muito pequenos

**Sintoma:**
```
ℹ️ Lote calculado abaixo do mínimo. Usando mínimo: 0.01
   💡 Para conta pequena ($100.00), considere reduzir SL ou aumentar % de risco
```

**Soluções:**
1. Aumentar `AccountRiskPerTradePercent` para 1.5% ou 2%
2. Reduzir `FixedSL_Points` (cuidado com stop muito apertado)
3. Desabilitar `EnableStateQualityRiskOverlay` temporariamente

### Problema: Circuit Breaker ativando muito

**Sintoma:**
Circuit breaker ativa todo dia, impedindo negociação.

**Soluções:**
1. Aumentar `DailyMaxLossPercent` para 7% ou 10%
2. Reduzir `AccountRiskPerTradePercent` para 0.5%
3. Revisar estratégia - pode estar em drawdown estrutural

### Problema: Lotes muito grandes

**Sintoma:**
Lotes chegando próximo ou no limite de 0.1.

**Soluções:**
1. Reduzir `MaxAllowedLot` para 0.05
2. Reduzir multiplicadores de qualidade:
   - `QualityMultiplier_Elite = 1.5` (ao invés de 2.0)
   - `QualityMultiplier_Good = 1.2` (ao invés de 1.5)

### Problema: Muitos trades cancelados

**Sintoma:**
```
⛔ TRADE CANCELADO - Qualidade muito baixa: -0.6
```

**Análise:**
- Isso é **normal** e **desejável**
- O EA está protegendo você de setups ruins
- Se TODOS os trades são cancelados, o modelo pode precisar re-treinar

**Soluções:**
1. Deixar o EA rodar por mais tempo para aprender
2. Verificar se os indicadores estão funcionando corretamente
3. Considerar ajustar os parâmetros de bloqueio de estado

### Problema: Margem insuficiente

**Sintoma:**
```
❌ Margem insuficiente para abrir posição
```

**Soluções:**
1. Reduzir `LotSize` para 0.01
2. Reduzir `AccountRiskPerTradePercent` para 0.5%
3. Verificar alavancagem da conta (mínimo 1:100 recomendado)
4. Fechar posições existentes antes de abrir novas

---

## 📚 Recursos Adicionais

### Arquivo de Configuração (.set)

Para salvar suas configurações:
1. Abra o Strategy Tester
2. Configure todos os parâmetros
3. Clique em "Save" e escolha um nome (ex: "Phoenix_100USD.set")
4. Use esse arquivo sempre que recarregar o EA

### Monitoramento Recomendado

Acompanhe estes logs no Journal:
- `💰 CIRCUIT BREAKER UPDATE` - P&L acumulado
- `🎯 RISK OVERLAY` - Qualidade dos estados
- `🚨 CIRCUIT BREAKER ATIVADO` - Quando proteção entra em ação
- `📊 LOT DECISION SUMMARY` - Decisão final de lote

### Backtest Recomendado

Antes de usar em conta real:
1. Rode backtest de 3-6 meses
2. Verifique se circuit breakers funcionam corretamente
3. Analise a distribuição de tamanhos de lote
4. Confirme que o drawdown máximo é aceitável

---

## ⚠️ Avisos Importantes

1. **Trading é Arriscado**: Mesmo com proteções, você pode perder dinheiro
2. **Comece Pequeno**: Use conta demo ou micro-conta primeiro
3. **Monitore Sempre**: Circuit breakers não garantem lucro
4. **Ajuste Conforme Necessário**: Cada mercado é diferente
5. **Respeite os Limites**: Não desabilite os circuit breakers em momento de perda

---

## 📞 Suporte

Se encontrar problemas ou tiver dúvidas:
1. Verifique os logs no Journal do MT5
2. Consulte este guia
3. Rode um backtest para validar comportamento
4. Reporte issues específicos com logs detalhados

---

**Versão do Documento:** 3.08  
**Última Atualização:** 2026-02-06  
**Compatível com:** Phoenix Trader v3.08+

---

## 🎉 Boa Sorte!

Com essas configurações, seu Phoenix Trader está otimizado para contas pequenas de $100, com proteção robusta contra perdas excessivas e gestão inteligente de risco por qualidade de estado.

**Lembre-se:** A chave para o sucesso é a disciplina e a paciência. Deixe o EA aprender e evoluir! 🚀
