# 🎯 Cartão de Referência Rápida - Conta de $100

## ⚙️ Configuração Essencial

```mql5
// 1️⃣ ATIVAR LOTE POR PORCENTAGEM
UsePercentageBasedLot = true       // ⭐ ESSENCIAL!
RiskPercentPerTrade = 1.5          // 1.5% da conta

// 2️⃣ CIRCUIT BREAKER DIÁRIO
EnableDailyCircuitBreaker = true
MaxDailyLossPercent = 5.0          // Máx: $5
MaxDailyLossDollars = 5.0

// 3️⃣ CIRCUIT BREAKER SEMANAL
EnableWeeklyCircuitBreaker = true
MaxWeeklyLossPercent = 15.0        // Máx: $15
MaxWeeklyLossDollars = 15.0

// 4️⃣ RISK OVERLAY
UseRiskOverlay = true
MinStateQualityForTrade = -0.5
ReduceLotOnLowQuality = true
LowQualityLotMultiplier = 0.5
```

---

## 📊 Tabela de Risco por Conta

| Saldo | 1.5% Risco | Lote (aprox) | Perda Máx/Dia |
|-------|------------|--------------|---------------|
| $100  | $1.50      | 0.004        | $5            |
| $150  | $2.25      | 0.006        | $7.50         |
| $200  | $3.00      | 0.009        | $10           |
| $300  | $4.50      | 0.013        | $15           |
| $500  | $7.50      | 0.021        | $25           |

---

## 🚦 Semáforo de Proteções

### 🟢 VERDE - Pode Operar
- Lucro do dia ou perda < $5
- Qualidade do estado ≥ -0.5
- Menos de MaxTradesPerDay

### 🟡 AMARELO - Operando com Redução
- Qualidade do estado entre -0.5 e 0.0
- Lote reduzido para 50%
- Continua operando com cautela

### 🔴 VERMELHO - BLOQUEADO
- Perda do dia ≥ $5 OU 5%
- Perda da semana ≥ $15 OU 15%
- Qualidade do estado < -0.5
- ⛔ SEM NOVAS OPERAÇÕES

---

## 📈 Progressão de Conta

### Semana 1: $100 → $110 (+10%)
```
Dia 1: +$3.50  → $103.50
Dia 2: -$2.00  → $101.50
Dia 3: +$4.20  → $105.70
Dia 4: +$2.80  → $108.50
Dia 5: +$1.50  → $110.00
```
✅ Lucro semanal: $10 (não atingiu limite)

### Semana com Circuit Breaker

```
Dia 1: -$2.50  → $97.50
Dia 2: -$1.80  → $95.70
Dia 3: -$1.20  → $94.50
💥 Perda total: $5.50 (5.5%)
🚨 CIRCUIT BREAKER ATIVADO
Dia 4-5: SEM TRADES (bloqueado)
```

---

## 💡 Dicas Práticas

### ✅ FAÇA
- Comece com $100-$150
- Use 1.5% de risco (conservador)
- Ative TODAS as proteções
- Monitore logs diariamente
- Respeite o circuit breaker

### ❌ NÃO FAÇA
- Não use menos de $100
- Não desative proteções
- Não force trades quando bloqueado
- Não use mais de 3% de risco
- Não ignore os avisos

---

## 🔍 Verificação Rápida

### Ao Inicializar o EA

Procure nos logs:
```
✅ "Circuit Breaker inicializado"
✅ "Saldo inicial: $100.00"
✅ "Modo: Lote por % da conta (1.5% por trade)"
✅ "Perda máxima diária: 5.0% ou $5.00"
```

### Durante Operação

Procure nos logs:
```
✅ "LOTE POR %: Conta=$100.00 | Risco=1.5%"
✅ "Lucros - Diário: $X.XX | Semanal: $Y.YY"
```

### Se Circuit Breaker Ativar

Você verá:
```
🚨🚨🚨 CIRCUIT BREAKER DIÁRIO ATIVADO!
💥 Perda diária: $5.20 (5.2%)
⛔ Trading bloqueado até amanhã!
```

---

## 🎯 Meta Mensal

### Conservador: +10% ao mês
- $100 → $110 (1º mês)
- $110 → $121 (2º mês)
- $121 → $133 (3º mês)
- Em 6 meses: $177
- Em 12 meses: $313

### Moderado: +20% ao mês
- $100 → $120 (1º mês)
- $120 → $144 (2º mês)
- $144 → $173 (3º mês)
- Em 6 meses: $298
- Em 12 meses: $891

*Resultados dependem de mercado e qualidade dos trades*

---

## ⚠️ Alertas Importantes

### Saldo Muito Baixo
```
⚠️ AVISO: Saldo muito baixo ($48.00)
```
**Ação**: Depositar mais ou parar de operar

### Circuit Breaker Ativo
```
⛔ Circuit Breaker Diário Ativo
```
**Ação**: Aguardar até meia-noite

### Estado de Baixa Qualidade
```
🛡️ RISK OVERLAY: Lote reduzido
```
**Ação**: Normal, sistema protegendo

---

## 📞 Checklist Diário

- [ ] Verificar saldo inicial do dia
- [ ] Confirmar circuit breaker resetado
- [ ] Monitorar lucro/perda acumulado
- [ ] Observar qualidade dos estados
- [ ] Revisar trades executados
- [ ] Verificar se próximo dos limites

---

## 🏆 Metas de Proteção

| Período | Perda Máxima | Reset |
|---------|--------------|-------|
| **Dia** | $5 ou 5% | Meia-noite |
| **Semana** | $15 ou 15% | Segunda-feira |
| **Mês** | ~$60 ou 20%* | Manual |

*Limite mensal não automático, apenas referência

---

## 🔧 Ajustes Finos

### Se perdendo muito:
```mql5
RiskPercentPerTrade = 1.0          // Reduzir para 1%
MaxDailyLossPercent = 3.0          // Mais restritivo
```

### Se indo bem:
```mql5
RiskPercentPerTrade = 2.0          // Aumentar para 2%
MaxDailyLossPercent = 6.0          // Mais flexível
```

---

**📌 LEMBRE-SE**: O objetivo é SOBREVIVER primeiro, LUCRAR depois!

As proteções existem para manter você no jogo. Use-as! 🛡️✅
