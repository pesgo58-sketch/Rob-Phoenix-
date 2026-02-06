# 🚀 Rob-Phoenix - Expert Advisor MetaTrader 5

## 📋 Sobre o Projeto

**Phoenix Trader** é um Expert Advisor (EA) avançado para MetaTrader 5 com sistema de aprendizado Q-Learning, gestão inteligente de risco e proteção robusta contra perdas.

### ✨ Versão Atual: 3.08

## 🎯 Principais Funcionalidades

### 🧠 Sistema de Aprendizado
- **Q-Learning Adaptativo** - Aprende com cada trade e melhora ao longo do tempo
- **576 Estados de Mercado** - Análise multidimensional (RSI, MACD, ATR, MA, Volume, Tempo)
- **Sistema de Bloqueio Inteligente** - Bloqueia automaticamente estados com má performance
- **Memória Persistente** - Salva e carrega conhecimento entre sessões

### 💰 Gestão de Risco Avançada (v3.08)
- **Risk Overlay por Qualidade de Estado**
  - Ajusta tamanho da posição baseado na qualidade do setup
  - Categorias: Elite (2.0x), Good (1.5x), Neutral (1.0x), Bad (0.5x)
  
- **Circuit Breakers Automáticos**
  - Proteção Diária: Para negociação se perder mais que X% por dia
  - Proteção Semanal: Para negociação se perder mais que X% por semana
  - Reset automático no novo período

- **Gestão Baseada em Percentual**
  - Calcula lote automaticamente baseado em % do saldo
  - Adapta-se quando o saldo cresce ou diminui
  - Ideal para contas pequenas (~$100)

### 📊 Análise Técnica
- Média Móvel (MA) para tendência
- RSI para momentum
- ATR para volatilidade
- Bollinger Bands para sobrecompra/sobrevenda
- Filtros de volume

### 🎮 Controles de Negociação
- Piramidação inteligente (até 4 posições)
- Trailing Stop dinâmico
- Limites diários e por direção
- Filtros de volatilidade e volume

## 🛡️ Especial para Contas Pequenas

A versão 3.08 foi otimizada para contas a partir de **$100**:

### Configuração Recomendada para $100

```
LotSize = 0.01                        // Lote mínimo
MaxAllowedLot = 0.1                   // Limite de segurança
AccountRiskPerTradePercent = 1.0      // Risco 1% = $1 por trade

DailyMaxLossPercent = 5.0             // Parar se perder $5 no dia
WeeklyMaxLossPercent = 10.0           // Parar se perder $10 na semana

FixedSL_Points = 35000                // 350 pips de Stop Loss
FixedTP_Points = 70000                // 700 pips de Take Profit (R:R 1:2)
```

### Proteções Automáticas
- ✅ Lote nunca excede margem disponível
- ✅ Circuit breakers param negociação em caso de perdas excessivas
- ✅ Risk overlay reduz aposta em setups ruins
- ✅ Limites diários e semanais de trades

## 📚 Documentação

- **[Guia de Configuração para Contas Pequenas](CONFIGURACAO_CONTA_PEQUENA.md)** - Tutorial completo
- **[Changelog v3.08](CHANGELOG_v308.md)** - Detalhes técnicos das mudanças

## 🚀 Como Usar

### 1. Instalação
1. Copie `robo phoenix` para a pasta `Experts` do seu MT5
2. Compile o arquivo no MetaEditor (F7)
3. Arraste para o gráfico ou abra Strategy Tester

### 2. Configuração Inicial
1. Se for conta pequena ($100-$500), use as configurações recomendadas acima
2. Habilite todas as proteções (Circuit Breakers)
3. Configure Risk Overlay para ajuste automático de lote
4. Rode um backtest de 3-6 meses primeiro

### 3. Monitoramento
Acompanhe estes indicadores no Journal:
- `💰 CIRCUIT BREAKER UPDATE` - P&L acumulado
- `🎯 RISK OVERLAY` - Qualidade dos estados
- `🚨 CIRCUIT BREAKER ATIVADO` - Quando proteção entra em ação

### 4. Ajustes
- Se circuit breaker ativa muito: Aumente limites ou reduza risco por trade
- Se lotes muito pequenos: Aumente % de risco ou reduza SL
- Se muitos trades cancelados: EA está protegendo você, é normal

## ⚙️ Parâmetros Principais

### Gestão de Risco
- `UseAccountRiskPercent` - Usar % do saldo (recomendado: true)
- `AccountRiskPerTradePercent` - % de risco por trade (padrão: 1.0%)
- `EnableStateQualityRiskOverlay` - Ajustar por qualidade (padrão: true)

### Circuit Breakers
- `EnableDailyCircuitBreaker` - Proteção diária (padrão: true)
- `DailyMaxLossPercent` - Limite diário em % (padrão: 5.0%)
- `EnableWeeklyCircuitBreaker` - Proteção semanal (padrão: true)
- `WeeklyMaxLossPercent` - Limite semanal em % (padrão: 10.0%)

### Limites
- `MaxTradesPerDay` - Máximo de trades por dia (padrão: 30)
- `ConsecutiveLossLimit` - Parar após N perdas seguidas (padrão: 15)
- `MaxAllowedLot` - Lote máximo permitido (padrão: 0.1 para contas pequenas)

## 📊 Indicadores Utilizados

O EA utiliza os seguintes indicadores técnicos:
- **MA (Moving Average)** - Identificação de tendência
- **RSI (Relative Strength Index)** - Medição de momentum
- **ATR (Average True Range)** - Medição de volatilidade
- **Bollinger Bands** - Identificação de extremos
- **Volume** - Confirmação de movimentos

## ⚠️ Avisos Importantes

1. **Trading é Arriscado** - Você pode perder seu capital investido
2. **Teste Primeiro** - Sempre rode backtest e forward test antes de usar em conta real
3. **Comece Pequeno** - Use conta demo ou micro-conta inicialmente
4. **Monitore Sempre** - Circuit breakers ajudam mas não garantem lucro
5. **Respeite os Limites** - Não desabilite proteções em momento de perda

## 🔧 Requisitos

- MetaTrader 5 (build 3000+)
- Conta com alavancagem mínima 1:100 (recomendado para $100)
- Símbolo com lote mínimo 0.01
- Spread competitivo (preferencialmente < 2 pips)

## 📈 Performance

### Características do Sistema
- Aprende continuamente com cada trade
- Bloqueia automaticamente estados ruins
- Adapta risco baseado na qualidade do setup
- Protege contra sequências de perdas

### O que Esperar
- **Primeiras semanas**: EA está aprendendo, performance variável
- **Após 100-200 trades**: Comportamento mais estável
- **Após 500+ trades**: Sistema maduro, bloqueios efetivos

## 🆘 Suporte

### Problemas Comuns

**1. Lotes muito pequenos**
- Aumente `AccountRiskPerTradePercent`
- Reduza `FixedSL_Points`
- Desabilite temporariamente `EnableStateQualityRiskOverlay`

**2. Circuit Breaker ativa muito**
- Aumente `DailyMaxLossPercent`
- Reduza `AccountRiskPerTradePercent`
- Revise se está em drawdown estrutural

**3. Muitos trades cancelados**
- É normal e saudável (proteção contra setups ruins)
- Se TODOS são cancelados, EA pode precisar re-treinar
- Deixe rodar por mais tempo para aprender

## 📜 Histórico de Versões

### v3.08 (2026-02-06) - Atual ✨
- ✅ Risk Overlay por qualidade de estado
- ✅ Circuit Breakers diário e semanal
- ✅ Gestão de risco baseada em %
- ✅ Otimização para contas pequenas ($100+)
- ✅ Documentação completa em português

### v3.07
- Sistema de bloqueio unificado
- Correções em contagem de visitas
- Decay funcional e reset inteligente

## 📄 Licença

Uso pessoal e educacional permitido.

## 🤝 Contribuições

Este é um projeto em desenvolvimento ativo. Sugestões e melhorias são bem-vindas.

---

**Desenvolvido por:** Phoenix Trader Team  
**Versão:** 3.08  
**Última Atualização:** 2026-02-06

---

## 🎯 Comece Agora

1. Leia o [Guia de Configuração para Contas Pequenas](CONFIGURACAO_CONTA_PEQUENA.md)
2. Configure o EA com os parâmetros recomendados
3. Rode um backtest de validação
4. Teste em conta demo por 1-2 semanas
5. Transite para conta real com cautela

**Boa sorte e bons trades! 🚀**
