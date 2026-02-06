# Phoenix Trader v3.08 - Resumo das Mudanças

## 📋 Visão Geral

Esta versão adiciona proteção robusta contra perdas e gestão de risco adaptativa para contas pequenas (~$100).

## 🆕 Novas Funcionalidades

### 1. 💰 Gestão de Risco Baseada em Percentual

**Novos Parâmetros:**
- `UseAccountRiskPercent` (bool, padrão: true)
- `AccountRiskPerTradePercent` (double, padrão: 1.0%)

**Funcionamento:**
- Calcula automaticamente o tamanho do lote baseado em % do saldo
- Exemplo: Com $100 e 1% de risco, arrisca $1 por trade
- Adapta-se automaticamente quando o saldo cresce/diminui

**Nova Função:**
```cpp
double CalculateBaseLotFromRisk(double riskPercent, double slPoints)
```

### 2. 🎯 Risk Overlay por Qualidade de Estado

**Novos Parâmetros:**
- `EnableStateQualityRiskOverlay` (bool, padrão: true)
- `QualityMultiplier_Elite` (double, padrão: 2.0x)
- `QualityMultiplier_Good` (double, padrão: 1.5x)
- `QualityMultiplier_Neutral` (double, padrão: 1.0x)
- `QualityMultiplier_Bad` (double, padrão: 0.5x)

**Funcionamento:**
- Analisa a qualidade do estado de mercado (-2.0 a +2.0)
- Ajusta automaticamente o tamanho da posição:
  - **Elite** (>0.8): Dobra o lote (2.0x)
  - **Good** (0.3-0.8): Aumenta 50% (1.5x)
  - **Neutral** (0.0-0.3): Lote normal (1.0x)
  - **Bad** (<0.0): Reduz pela metade (0.5x)
  - **Muito Bad** (<-0.5): Cancela trade automaticamente

**Nova Função:**
```cpp
double ApplyStateQualityRiskOverlay(int state, double baseLot)
```

### 3. 🚨 Circuit Breakers Diário e Semanal

**Novos Parâmetros:**
- `EnableDailyCircuitBreaker` (bool, padrão: true)
- `DailyMaxLossPercent` (double, padrão: 5.0%)
- `DailyMaxLossCurrency` (double, padrão: $5)
- `EnableWeeklyCircuitBreaker` (bool, padrão: true)
- `WeeklyMaxLossPercent` (double, padrão: 10.0%)
- `WeeklyMaxLossCurrency` (double, padrão: $10)

**Funcionamento:**
- Monitora P&L acumulado em tempo real
- Bloqueia novas entradas se limites forem atingidos
- Reset automático no início do novo período
- Dupla proteção: por percentual E por valor absoluto

**Novas Funções:**
```cpp
bool CheckCircuitBreakers()
void ResetDailyTracking()
void ResetWeeklyTracking()
```

**Novas Variáveis Globais:**
```cpp
double g_dailyPnL
double g_dailyStartBalance
datetime g_dailyStartDate
bool g_dailyCircuitBreakerActive

double g_weeklyPnL
double g_weeklyStartBalance
datetime g_weeklyStartDate
bool g_weeklyCircuitBreakerActive
```

### 4. 💼 Adaptação para Contas Pequenas

**Parâmetros Ajustados:**
- `MaxAllowedLot` alterado de 1.0 para **0.1**
  - Limita exposição máxima em contas pequenas
  - Previne over-leverage acidental

**Melhorias:**
- Mensagens de log específicas para contas pequenas
- Sugestões automáticas quando lote calculado é muito pequeno
- Validação rigorosa de margem disponível

## 🔄 Mudanças no Fluxo de Execução

### ExecuteAction() - Ordem de Verificações

**ANTES:**
1. Verificar estado bloqueado
2. Verificar volume
3. Verificar direção permitida
4. Verificar tempo entre trades
5. Verificar volatilidade
6. Verificar indicadores
7. **Calcular lote fixo ou SmartLot**
8. Abrir posição

**DEPOIS:**
1. **✨ NOVO: Verificar Circuit Breakers (PRIMEIRO)**
2. Verificar estado bloqueado
3. Verificar volume
4. Verificar direção permitida
5. Verificar tempo entre trades
6. Verificar volatilidade
7. Verificar indicadores
8. **✨ NOVO: Calcular lote base por % de risco**
9. **✨ NOVO: Aplicar overlay de qualidade**
10. Aplicar SmartLot tradicional (se overlay desabilitado)
11. Validar limites de símbolo
12. Abrir posição

### OnTradeTransaction() - Tracking Adicional

**Adicionado:**
```cpp
// Atualizar P&L dos circuit breakers
g_dailyPnL += net_profit;
g_weeklyPnL += net_profit;

// Log detalhado
Print("💰 CIRCUIT BREAKER UPDATE:");
Print("   📊 P&L deste trade: $", net_profit);
Print("   📅 P&L diário acumulado: $", g_dailyPnL);
Print("   📆 P&L semanal acumulado: $", g_weeklyPnL);
```

### OnInit() - Inicialização Circuit Breakers

**Adicionado:**
```cpp
// Inicializar tracking de circuit breakers
g_dailyPnL = 0.0;
g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
g_dailyStartDate = TimeCurrent();
g_dailyCircuitBreakerActive = false;

g_weeklyPnL = 0.0;
g_weeklyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
g_weeklyStartDate = TimeCurrent();
g_weeklyCircuitBreakerActive = false;
```

## 📊 Exemplos de Logs

### Cálculo de Lote com Risk Overlay

```
💰 LOTE BASE (% RISCO): 0.01 (1.00% de risco)
🎯 RISK OVERLAY: Estado=245 | Qualidade=0.850 | Categoria=💎 ELITE | Multiplicador=2.00x | LoteBase=0.01 → LoteAjustado=0.02
📊 LOT DECISION SUMMARY: 💎 ELITE → BaseLot=0.01 | AfterOverlay=0.02 | SmartMult=1.00 | FinalLot=0.02 | Quality=0.850 | PyramidLevel=0
```

### Circuit Breaker Ativado

```
🚨🚨🚨 CIRCUIT BREAKER DIÁRIO ATIVADO 🚨🚨🚨
   📉 Perda diária: -5.20% (limite: 5.00%)
   💰 P&L do dia: $-5.20
   ⛔ NOVAS ENTRADAS BLOQUEADAS ATÉ AMANHÃ
```

### Trade Bloqueado por Circuit Breaker

```
🚨🚨🚨 CIRCUIT BREAKER ATIVO - Trade cancelado por proteção de risco
🚨 Circuit Breaker Diário Ativo
```

### Tracking de P&L

```
💰 CIRCUIT BREAKER UPDATE:
   📊 P&L deste trade: $-1.50
   📅 P&L diário acumulado: $-3.50
   📆 P&L semanal acumulado: $-5.20
```

## 🎯 Configuração Recomendada para $100

```
// Básico
LotSize = 0.01
MaxAllowedLot = 0.1

// Risk Management
UseAccountRiskPercent = true
AccountRiskPerTradePercent = 1.0

// Risk Overlay
EnableStateQualityRiskOverlay = true
QualityMultiplier_Elite = 2.0
QualityMultiplier_Good = 1.5
QualityMultiplier_Neutral = 1.0
QualityMultiplier_Bad = 0.5

// Circuit Breakers
EnableDailyCircuitBreaker = true
DailyMaxLossPercent = 5.0
DailyMaxLossCurrency = 5.0

EnableWeeklyCircuitBreaker = true
WeeklyMaxLossPercent = 10.0
WeeklyMaxLossCurrency = 10.0

// Stops
FixedSL_Points = 35000  // 350 pips
FixedTP_Points = 70000  // 700 pips (R:R 1:2)

// SmartLot Tradicional
EnableSmartLot = false  // Desabilitar se usar Risk Overlay
```

## 📁 Arquivos Modificados

### robo phoenix
- **Linhas alteradas:** ~430 linhas adicionadas/modificadas
- **Novas seções:**
  - Parâmetros de entrada (linhas ~145-170)
  - Variáveis globais (linhas ~420-435)
  - Funções de cálculo de risco (linhas ~4664-4796)
  - Funções de circuit breaker (linhas ~5620-5760)
  - Integração em ExecuteAction (linhas ~4148-4370)
  - Tracking em OnTradeTransaction (linhas ~6089-6096)
  - Inicialização em OnInit (linhas ~7285-7295)

### Novos Arquivos
- `CONFIGURACAO_CONTA_PEQUENA.md` - Guia completo de configuração

## ✅ Validação

### Testes Recomendados

1. **Teste de Lote por % de Risco**
   - Verificar se lote aumenta quando saldo aumenta
   - Verificar se respeita limites do símbolo
   - Testar com diferentes valores de AccountRiskPerTradePercent

2. **Teste de Risk Overlay**
   - Verificar multiplicadores por categoria de qualidade
   - Confirmar que trades ruins são reduzidos/cancelados
   - Verificar que trades Elite aumentam apropriadamente

3. **Teste de Circuit Breaker Diário**
   - Simular perdas até atingir limite
   - Verificar que novas entradas são bloqueadas
   - Verificar reset no dia seguinte

4. **Teste de Circuit Breaker Semanal**
   - Simular perdas até atingir limite semanal
   - Verificar bloqueio de entradas
   - Verificar reset na nova semana

5. **Teste com Conta $100**
   - Rodar backtest com saldo inicial de $100
   - Verificar que lotes ficam entre 0.01-0.1
   - Confirmar que margem é sempre suficiente
   - Validar que circuit breakers protegem adequadamente

## 🔒 Compatibilidade

### Backward Compatibility
- ✅ Todos os parâmetros antigos mantidos
- ✅ SmartLot tradicional ainda funciona
- ✅ Arquivos .set antigos são compatíveis
- ✅ Sistema de aprendizado preservado

### Desabilitar Novas Funcionalidades
```
UseAccountRiskPercent = false           // Usar LotSize fixo
EnableStateQualityRiskOverlay = false   // Usar SmartLot tradicional
EnableDailyCircuitBreaker = false       // Desabilitar proteção diária
EnableWeeklyCircuitBreaker = false      // Desabilitar proteção semanal
```

## 🚀 Próximos Passos

1. **Testar em Strategy Tester**
   - Rodar backtest de 3-6 meses
   - Analisar logs e comportamento
   - Validar circuit breakers

2. **Testar em Conta Demo**
   - Usar saldo real de $100
   - Monitorar por 1-2 semanas
   - Ajustar parâmetros conforme necessário

3. **Transição para Conta Real**
   - Começar com valores conservadores
   - Aumentar risco gradualmente se funcionar bem
   - Sempre respeitar os circuit breakers

## 📞 Suporte

Problemas conhecidos: Nenhum até o momento.

Para reportar bugs ou sugerir melhorias:
1. Incluir versão do EA (3.08)
2. Incluir logs relevantes do Journal
3. Descrever configuração usada
4. Descrever comportamento esperado vs observado

---

**Versão:** 3.08  
**Data:** 2026-02-06  
**Autor:** Phoenix Trader Team  
**Status:** ✅ Pronto para Testes
