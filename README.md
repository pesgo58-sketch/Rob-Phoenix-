# Phoenix Trader - Robô de Trading MQL5

## 🚀 Versão 3.08 - Risk Overlay + Circuit Breaker

Robô de trading automatizado para MetaTrader 5 com sistema de aprendizado Q-Learning e proteções avançadas para contas pequenas.

## ✨ Novidades da Versão 3.08

### 🛡️ Risk Overlay por Qualidade de Estado
- **Ajuste automático de lote** baseado no tamanho da conta e qualidade do estado
- **Multiplicadores de risco por qualidade**:
  - ELITE (win rate ≥65%, Q-value alto): 1.5x risco
  - BOM (win rate ≥55%): 1.2x risco
  - NEUTRO: 1.0x risco base
  - RUIM (win rate <35%): 0.5x risco
  - BLOQUEADO: 0.0x (não opera)
- Otimizado para contas de **~$100 USD**

### ⛔ Circuit Breaker Diário/Semanal
- **Proteção contra drawdown excessivo**:
  - Circuit breaker diário: para trading após 5% de perda
  - Circuit breaker semanal: para trading após 15% de perda
  - Reset automático ao trocar de dia/semana
- Visível no HUD em tempo real

### 🔧 Correções de Bloqueio de Estados
Resolvido o problema de "travamento" onde o robô parava de operar:
- **Decay desabilitado por padrão** (evita redução prematura de visitas)
- **MinVisitsForBlockDecision aumentado** de 30 para 50
- **BlockLossRateThreshold aumentado** de 80% para 85%
- **UnblockWinRateThreshold reduzido** de 55% para 40%
- **NOP bias ajustado** (menos escolha de NOP forçado)

## ⚙️ Configuração para Conta de $100

### Parâmetros Recomendados:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🛡️ RISCO GLOBAL E CIRCUIT BREAKER
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EnableRiskOverlay             = true
AccountReferenceBalance       = 100.0    // Seu saldo inicial
MaxDailyLossPercent           = 5.0      // 5% = $5 de perda máxima/dia
MaxWeeklyLossPercent          = 15.0     // 15% = $15 de perda máxima/semana
MaxRiskPerTradePercent        = 1.0      // 1% = $1 por trade (neutro)
EliteRiskMultiplier           = 1.5      // Elite: $1.50 por trade
GoodRiskMultiplier            = 1.2      // Bom: $1.20 por trade
BadRiskMultiplier             = 0.5      // Ruim: $0.50 por trade
BlockedRiskMultiplier         = 0.0      // Bloqueado: não opera
UseEquityForRisk              = true     // Usar equity (recomendado)
EnableDailyCircuitBreaker     = true
EnableWeeklyCircuitBreaker    = true

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💰 NEGOCIAÇÃO BÁSICA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
LotSize                       = 0.01     // Lote mínimo

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔄 DECAY E RESET
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EnableMemoryDecay             = false    // ⚠️ DESABILITADO (evita travamento)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🚫 BLOQUEIO DE ESTADOS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
MinVisitsForBlockDecision     = 50       // Aumentado para 50
BlockLossRateThreshold        = 0.85     // 85% de perdas para bloquear
UnblockWinRateThreshold       = 0.40     // 40% de vitórias para desbloquear
EnableBlockingDebugLog        = false    // Apenas para diagnóstico
```

### Para Contas Maiores:
- **$200**: `AccountReferenceBalance = 200.0`, considere `MaxRiskPerTradePercent = 1.0%`
- **$500**: `AccountReferenceBalance = 500.0`, considere `MaxRiskPerTradePercent = 0.8%`
- **$1000+**: Ajuste proporcionalmente mantendo proteções ativas

## 📊 Interface (HUD)

O HUD mostra em tempo real:
- ✅ Estados descobertos e bloqueados
- 🎯 Win rate global
- 📈 PnL diário e semanal (% da conta)
- ⛔ Status do circuit breaker (quando ativo)
- 💰 Direção e posições ativas
- 🎲 Taxa de exploração

## 🔍 Diagnóstico de Problemas

### Robô parou de operar?
1. Verifique o HUD - circuit breaker ativo?
2. Verifique estados bloqueados (deve ser <30% dos estados descobertos)
3. Ative `EnableBlockingDebugLog = true` temporariamente
4. Verifique os logs para entender decisões de bloqueio/desbloqueio

### Perdas excessivas?
1. Reduza `MaxRiskPerTradePercent` (ex: 0.5%)
2. Reduza `MaxDailyLossPercent` (ex: 3%)
3. Considere ativar filtros de validação (RSI, BB, ADX)

### Estados bloqueando muito rápido?
1. Aumente `MinVisitsForBlockDecision` (ex: 70-100)
2. Aumente `BlockLossRateThreshold` (ex: 0.90)
3. Reduza `UnblockWinRateThreshold` (ex: 0.35)

## 🎯 Filosofia de Operação

1. **Aprendizado Gradual**: O robô explora diferentes condições de mercado
2. **Proteção Progressiva**: Estados ruins são bloqueados, mas podem ser desbloqueados se melhorarem
3. **Gestão de Risco Adaptativa**: Risco ajustado pela qualidade do estado
4. **Circuit Breaker**: Proteção final contra drawdown excessivo

## 📝 Arquivos

- `Phoenix_Trader_SIMPLIFIED.mq5` - Código principal do Expert Advisor
- `Phoenix_Files/Backups/state_memory.bin` - Memória persistente do Q-Learning (criado automaticamente)

## ⚠️ Avisos Importantes

- **Backtest vs Real**: Resultados de backtest não garantem resultados reais
- **Gestão de Risco**: Nunca arrisque mais do que pode perder
- **Conta Demo**: Teste sempre em conta demo primeiro
- **Decay Desabilitado**: Por padrão, o decay está desabilitado. Habilite apenas se entender as implicações
- **Monitoramento**: Acompanhe regularmente a performance do robô

## 📄 Licença

Phoenix Trader © 2024

---

**Versão**: 3.08  
**Última Atualização**: Fevereiro 2024  
**Compatibilidade**: MetaTrader 5
