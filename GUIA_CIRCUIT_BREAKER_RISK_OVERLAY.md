# 🛡️ Guia Completo - Circuit Breaker e Risk Management

## Visão Geral

O Phoenix Trader agora possui um sistema completo de proteção de risco com três camadas:

1. **Circuit Breaker Diário/Semanal** - Proteção contra perdas excessivas
2. **Risk Overlay por Qualidade** - Ajuste de risco baseado na qualidade do estado
3. **Suporte para Conta Pequena** - Começar com apenas $100

---

## 🚨 Circuit Breaker - Proteção Automática

### O Que É?

Circuit breaker é um sistema de proteção que **bloqueia automaticamente** todas as operações quando limites de perda são atingidos.

### Como Funciona?

**Diariamente**:
- Rastreia o lucro/prejuízo do dia
- Se perda atingir 5% OU $5: **BLOQUEIO ATÉ MEIA-NOITE**
- Reset automático à 00:00

**Semanalmente**:
- Rastreia o lucro/prejuízo da semana
- Se perda atingir 15% OU $15: **BLOQUEIO ATÉ SEGUNDA-FEIRA**
- Reset automático toda segunda-feira

### Parâmetros

```mql5
// CIRCUIT BREAKER DIÁRIO
EnableDailyCircuitBreaker = true    // Ativar proteção diária
MaxDailyLossPercent = 5.0           // Perda máxima: 5% do saldo
MaxDailyLossDollars = 5.0           // OU $5 (o que ocorrer primeiro)

// CIRCUIT BREAKER SEMANAL
EnableWeeklyCircuitBreaker = true   // Ativar proteção semanal
MaxWeeklyLossPercent = 15.0         // Perda máxima: 15% do saldo
MaxWeeklyLossDollars = 15.0         // OU $15 (o que ocorrer primeiro)
```

### Exemplo Prático

**Conta de $100**:

**Dia 1**:
- Saldo inicial: $100
- Trade 1: -$2
- Trade 2: -$1.50
- Trade 3: -$1.80
- **Total perdido: $5.30 (5.3%)**
- 🚨 **CIRCUIT BREAKER ATIVADO**
- ⛔ Sem mais trades até amanhã

**Dia 2** (novo dia):
- Reset automático à meia-noite
- Pode operar novamente

### Mensagens do Circuit Breaker

```
🚨🚨🚨 CIRCUIT BREAKER DIÁRIO ATIVADO!
💥 Perda diária: $5.30 (5.3%)
⛔ Trading bloqueado até amanhã!
```

```
🔄 RESET DIÁRIO - Novo dia de trading
```

---

## 🛡️ Risk Overlay - Proteção por Qualidade de Estado

### O Que É?

Risk Overlay ajusta o risco baseado na **qualidade do estado** atual. Estados ruins = menos risco.

### Como Funciona?

O sistema calcula a qualidade de cada estado (baseado em Q-values e win rate) e:

1. **Quality < -0.5**: 🚫 **BLOQUEIA O TRADE**
2. **Quality < 0.0**: ⚠️ **REDUZ LOTE PARA 50%**
3. **Quality ≥ 0.0**: ✅ **LOTE NORMAL**

### Parâmetros

```mql5
UseRiskOverlay = true                // Ativar overlay de risco
MinStateQualityForTrade = -0.5       // Qualidade mínima para operar
ReduceLotOnLowQuality = true         // Reduzir lote em baixa qualidade
LowQualityThreshold = 0.0            // Threshold de baixa qualidade
LowQualityLotMultiplier = 0.5        // 50% do lote em baixa qualidade
```

### Exemplo Prático

**Estado com Quality = -0.8** (muito ruim):
```
🛡️ RISK OVERLAY: Estado bloqueado por qualidade muito baixa
   Quality=-0.8 | Mínimo=-0.5
❌ Trade NÃO executado
```

**Estado com Quality = -0.2** (baixa):
```
🛡️ RISK OVERLAY: Lote reduzido por baixa qualidade
   Quality=-0.2 | Multiplicador=0.50 | Novo lote=0.005
✅ Trade executado com METADE do lote
```

**Estado com Quality = 0.5** (boa):
```
✅ Trade executado com lote NORMAL
```

### Benefícios

- ✅ Evita operar em estados ruins
- ✅ Reduz exposição em estados incertos
- ✅ Maximiza ganhos em estados bons
- ✅ Proteção automática e inteligente

---

## 💰 Suporte para Conta Pequena ($100)

### O Que É?

Sistema que permite começar com apenas $100 calculando automaticamente o tamanho do lote baseado em **porcentagem de risco**.

### Como Funciona?

Em vez de usar um lote fixo (ex: 0.01), o EA calcula o lote baseado em:
- Tamanho da conta
- Porcentagem de risco desejada
- Stop Loss em pontos

**Fórmula**:
```
RiskAmount = Account × (RiskPercent / 100)
Lot = RiskAmount / (SL_Points × PointValue)
```

### Parâmetros

```mql5
MinAccountBalance = 100.0            // Saldo mínimo recomendado
UsePercentageBasedLot = true         // 🔥 ATIVAR para calcular automaticamente
RiskPercentPerTrade = 1.5            // Risco por trade: 1.5%
```

### Exemplo Prático

**Configuração**:
- Conta: $100
- RiskPercentPerTrade: 1.5%
- SL: 350 pontos

**Cálculo Automático**:
```
💰 LOTE POR %: Conta=$100.00 | Risco=1.5% | RiskAmount=$1.50 | Lote=0.004
```

**Evolução da Conta**:

| Saldo | Risco 1.5% | Lote Calculado |
|-------|------------|----------------|
| $100 | $1.50 | 0.004 |
| $150 | $2.25 | 0.006 |
| $200 | $3.00 | 0.009 |

O lote **cresce** conforme a conta cresce! 📈

### Avisos

```
⚠️ AVISO: Saldo muito baixo ($48.00)
⚠️ Recomendado: Pelo menos $100.00
```

---

## 📋 Configuração Recomendada para $100

### Setup Conservador (Iniciante)

```mql5
// ===== CIRCUIT BREAKER =====
EnableDailyCircuitBreaker = true
MaxDailyLossPercent = 5.0          // Máximo $5/dia
MaxDailyLossDollars = 5.0

EnableWeeklyCircuitBreaker = true
MaxWeeklyLossPercent = 15.0        // Máximo $15/semana
MaxWeeklyLossDollars = 15.0

// ===== CONTA PEQUENA =====
MinAccountBalance = 100.0
UsePercentageBasedLot = true       // ✅ ATIVAR
RiskPercentPerTrade = 1.5          // 1.5% = $1.50 por trade
LotSize = 0.01                     // Ignorado se UsePercentageBasedLot = true

// ===== RISK OVERLAY =====
UseRiskOverlay = true
MinStateQualityForTrade = -0.5     // Bloqueia apenas estados muito ruins
ReduceLotOnLowQuality = true
LowQualityThreshold = 0.0
LowQualityLotMultiplier = 0.5      // Metade do lote

// ===== STOPS =====
UseFixedSL = true
FixedSL_Points = 35000             // 350 pontos
UseFixedTP = true
FixedTP_Points = 70000             // 700 pontos (2:1 risk/reward)

// ===== LIMITES =====
MaxTradesPerDay = 10               // Máximo 10 trades/dia
ConsecutiveLossLimit = 5           // Parar após 5 perdas seguidas
```

### Setup Moderado (Intermediário)

```mql5
RiskPercentPerTrade = 2.0          // 2% = $2.00 por trade
MaxDailyLossPercent = 6.0          // Máximo $6/dia
MaxWeeklyLossPercent = 18.0        // Máximo $18/semana
MaxTradesPerDay = 15
```

### Setup Agressivo (Avançado)

```mql5
RiskPercentPerTrade = 3.0          // 3% = $3.00 por trade
MaxDailyLossPercent = 8.0          // Máximo $8/dia
MaxWeeklyLossPercent = 24.0        // Máximo $24/semana
MaxTradesPerDay = 20
```

---

## 🔄 Fluxo de Proteção

```
CADA TICK:
  ↓
CheckCircuitBreaker()
  ├─ Resetar contadores se novo dia/semana
  ├─ Verificar perda diária ($5 ou 5%)
  ├─ Verificar perda semanal ($15 ou 15%)
  └─ SE LIMITE ATINGIDO → ⛔ BLOQUEAR TRADING
  ↓
SE PASSOU:
  ↓
GetCurrentState()
  ↓
ChooseAction()
  ↓
ExecuteAction()
  ├─ SE UsePercentageBasedLot:
  │   └─ Calcular lote por % da conta
  ├─ SE UseRiskOverlay:
  │   ├─ Verificar qualidade do estado
  │   ├─ SE quality < -0.5 → ⛔ BLOQUEAR
  │   └─ SE quality < 0.0 → ⚠️ REDUZIR LOTE 50%
  └─ Executar trade
  ↓
OnTradeTransaction()
  ├─ Atualizar g_dailyProfit
  └─ Atualizar g_weeklyProfit
```

---

## 📊 Monitoramento

### Logs Importantes

**Inicialização**:
```
🛡️ Circuit Breaker inicializado:
   Saldo inicial: $100.00
   Modo: Lote por % da conta (1.5% por trade)
   Perda máxima diária: 5.0% ou $5.00
   Perda máxima semanal: 15.0% ou $15.00
```

**Cada Trade**:
```
💰 LOTE POR %: Conta=$102.50 | Risco=1.5% | RiskAmount=$1.54 | Lote=0.004
```

```
💰 Lucros - Diário: $2.50 | Semanal: $12.30
```

**Risk Overlay**:
```
🛡️ RISK OVERLAY: Lote reduzido por baixa qualidade
   Quality=-0.15 | Multiplicador=0.50 | Novo lote=0.002
```

**Circuit Breaker**:
```
🚨🚨🚨 CIRCUIT BREAKER DIÁRIO ATIVADO!
💥 Perda diária: $5.20 (5.2%)
⛔ Trading bloqueado até amanhã!
```

---

## ❓ Perguntas Frequentes

### 1. Posso usar com conta menor que $100?

Sim, mas NÃO recomendado. O sistema avisa se saldo < $50:
```
⚠️ AVISO: Saldo muito baixo ($45.00)
⚠️ Recomendado: Pelo menos $100.00
```

### 2. O que acontece se o circuit breaker ativar?

- Trading completamente bloqueado
- Posições abertas NÃO são fechadas (continua gerenciando)
- Novas operações proibidas até reset
- Reset automático (diário ou semanal)

### 3. Posso desativar o circuit breaker?

Sim, mas **NÃO RECOMENDADO**:
```mql5
EnableDailyCircuitBreaker = false
EnableWeeklyCircuitBreaker = false
```

### 4. O risk overlay funciona com lote fixo?

Sim! Risk overlay e lote por % são independentes:
- `UseRiskOverlay = true` + `UsePercentageBasedLot = false` → Lote fixo com proteção
- `UseRiskOverlay = true` + `UsePercentageBasedLot = true` → Lote % com proteção

### 5. Como sei se está funcionando?

Verifique os logs:
- ✅ "Circuit Breaker inicializado"
- ✅ "LOTE POR %: Conta=..."
- ✅ "RISK OVERLAY: ..."
- ✅ "Lucros - Diário: ... | Semanal: ..."

### 6. Perdi $5, mas circuit breaker não ativou?

Verifique:
- Saldo inicial do dia
- Perda pode ser em % OU $ (o que ocorrer primeiro)
- Exemplo: $5.20 ativa (> $5), mas 4.8% não ativa (< 5%)

---

## ✅ Checklist de Ativação

Para usar com conta de $100:

- [x] `MinAccountBalance = 100.0`
- [x] `UsePercentageBasedLot = true` ⭐
- [x] `RiskPercentPerTrade = 1.5`
- [x] `EnableDailyCircuitBreaker = true`
- [x] `MaxDailyLossPercent = 5.0`
- [x] `MaxDailyLossDollars = 5.0`
- [x] `EnableWeeklyCircuitBreaker = true`
- [x] `MaxWeeklyLossPercent = 15.0`
- [x] `MaxWeeklyLossDollars = 15.0`
- [x] `UseRiskOverlay = true`
- [x] `MinStateQualityForTrade = -0.5`
- [x] `ReduceLotOnLowQuality = true`

---

## 🎯 Resumo

| Proteção | Quando Ativa | Ação |
|----------|--------------|------|
| **Circuit Breaker Diário** | Perda ≥ 5% OU $5 | Bloqueia até meia-noite |
| **Circuit Breaker Semanal** | Perda ≥ 15% OU $15 | Bloqueia até segunda |
| **Risk Overlay (Block)** | Quality < -0.5 | Bloqueia trade |
| **Risk Overlay (Reduce)** | Quality < 0.0 | Reduz lote 50% |
| **Lote por %** | Sempre (se ativado) | Calcula lote automaticamente |

**Com estas proteções, você pode operar com $100 com segurança máxima!** 🛡️✅

---

**Data**: 2026-02-07  
**Versão**: Phoenix Trader v307F com Circuit Breaker  
**Status**: ✅ Pronto para Uso
