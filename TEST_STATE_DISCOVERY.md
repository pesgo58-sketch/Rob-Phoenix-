# Teste de Validação: Sistema de Descoberta de Estados

## Objetivo
Validar que o sistema de sincronização de estados descobertos funciona corretamente com o HUD.

## Pré-requisitos
- Robô Phoenix v307F instalado no MetaTrader 5
- Conta demo ou simulador
- HUD ativado (ShowHUD = true)

## Cenários de Teste

### Teste 1: Inicialização Limpa

**Objetivo**: Verificar inicialização correta do sistema

**Passos**:
1. Deletar arquivo `state_memory.bin` da pasta Common
2. Deletar arquivo `Cerebro_*.bin` da pasta Common
3. Iniciar o robô
4. Verificar Expert Journal

**Resultado Esperado**:
```
🔥🔥🔥 INICIALIZANDO SISTEMA SUPER CORRIGIDO...
📊 Estados descobertos: 0
✅ Novo cérebro criado (Sistema Super Corrigido v307F)
🖥️ HUD inicializado com X objetos
```

**HUD deve mostrar**:
```
Estados: 0/576
   [░░░░░░░░░░░░░░░░░░░░] (0.0%)
```

**Status**: ☐ Passou ☐ Falhou

---

### Teste 2: Primeira Descoberta de Estado

**Objetivo**: Validar descoberta e exibição do primeiro estado

**Passos**:
1. Aguardar cálculo do primeiro estado (OnTick)
2. Observar Expert Journal
3. Verificar HUD

**Resultado Esperado no Journal**:
```
📊 Estado calculado: X | RSI=... | MA_dist=... | ...
🆕 NOVO ESTADO DESCOBERTO: X | Total descobertos: 1 | Progresso: 0.2%
```

**HUD deve mostrar** (por 30 segundos):
```
Estados: 1/576
   [▓░░░░░░░░░░░░░░░░░░░] (0.2%)
   🆕 Novo: Estado #X (1 novos)     ← Em verde piscante
```

**Status**: ☐ Passou ☐ Falhou

---

### Teste 3: Múltiplas Descobertas

**Objetivo**: Verificar contador incremental e atualização do HUD

**Passos**:
1. Deixar robô executar por 5-10 minutos
2. Observar múltiplas descobertas no Journal
3. Verificar atualização do contador no HUD

**Resultado Esperado**:
- Cada nova descoberta loga no Journal
- Contador "Estados: X/576" aumenta
- Barra de progresso avança
- Label "🆕 Novo" aparece a cada descoberta

**Exemplo de progressão**:
```
Minuto 1: Estados: 1/576 (0.2%)
Minuto 3: Estados: 5/576 (0.9%)
Minuto 5: Estados: 12/576 (2.1%)
Minuto 10: Estados: 25/576 (4.3%)
```

**Status**: ☐ Passou ☐ Falhou

---

### Teste 4: Persistência de Dados

**Objetivo**: Verificar que estados descobertos são salvos e carregados

**Passos**:
1. Deixar robô descobrir alguns estados (ex: 10)
2. Anotar número de estados descobertos
3. Remover robô do gráfico (OnDeinit será chamado)
4. Aguardar 10 segundos
5. Adicionar robô novamente ao gráfico

**Resultado Esperado no Journal**:
```
💾 Salvando memória antes de fechar...
✅ Estados carregados da memória persistente
📊 Estados ativos: 10
📊 Estados descobertos: 10
```

**HUD deve mostrar**:
```
Estados: 10/576
   [▓▓░░░░░░░░░░░░░░░░░░] (1.7%)
```
(Mesmo valor de antes do restart)

**Status**: ☐ Passou ☐ Falhou

---

### Teste 5: Indicador Visual Temporizado

**Objetivo**: Validar que indicador de nova descoberta desaparece após 30 segundos

**Passos**:
1. Aguardar descoberta de novo estado
2. Observar label "🆕 Novo: Estado #X"
3. Aguardar exatamente 30 segundos
4. Verificar que label desaparece

**Resultado Esperado**:
- **0-30 seg**: Label visível, piscando verde/amarelo
- **Após 30 seg**: Label vazio, g_newStatesCount resetado

**Status**: ☐ Passou ☐ Falhou

---

### Teste 6: Exportação para Texto

**Objetivo**: Verificar que informações de descoberta são exportadas

**Passos**:
1. Aguardar exportação automática (60 minutos) OU
2. Chamar manualmente `ForceTextExport()` no código
3. Localizar arquivo em `Common/Files/Phoenix_Files/Text_Logs/`
4. Abrir arquivo `.txt`

**Resultado Esperado no arquivo**:
```
Estados totais possíveis: 576 (3×4×2×3×2×2×2 = 576)
Estados ativos na memória: X
Estados descobertos: X
Último estado descoberto: #Y em 2026-01-02 22:30:15
Estados bloqueados: Z
Taxa de descoberta: XX.X%
```

**Status**: ☐ Passou ☐ Falhou

---

### Teste 7: Sincronização com AddActiveState

**Objetivo**: Verificar que SyncStateDiscovery é chamado corretamente

**Passos**:
1. Adicionar Print temporário no início de `SyncStateDiscovery()`:
   ```mql5
   Print("DEBUG: SyncStateDiscovery chamado para estado ", state);
   ```
2. Executar robô
3. Observar Journal

**Resultado Esperado**:
- Para cada novo estado, duas mensagens:
  ```
  DEBUG: SyncStateDiscovery chamado para estado X
  🆕 NOVO ESTADO DESCOBERTO: X | Total descobertos: Y | Progresso: Z%
  ```
- **NUNCA** aparecer sync para estados já descobertos

**Status**: ☐ Passou ☐ Falhou

---

### Teste 8: Cache do HUD Invalidado

**Objetivo**: Confirmar que cache é invalidado ao descobrir estado

**Passos**:
1. Adicionar Print em `SyncStateDiscovery()`:
   ```mql5
   Print("DEBUG: Cache invalidado - cachedVisitedStates = ", cachedVisitedStates);
   ```
2. Executar robô
3. Verificar Journal

**Resultado Esperado**:
```
DEBUG: Cache invalidado - cachedVisitedStates = -1
```
(Valor -1 força recálculo no próximo UpdateHUDLight)

**Status**: ☐ Passou ☐ Falhou

---

## Testes de Integridade

### INT-1: Contador não Decrementa

**Verificação**: `g_totalStatesDiscovered` nunca diminui
- Executar robô por 1 hora
- Verificar que contador sempre aumenta ou permanece igual
- NUNCA deve diminuir

**Status**: ☐ Passou ☐ Falhou

---

### INT-2: Sem Estados Duplicados

**Verificação**: Estado não é contado duas vezes
- Adicionar log em `SyncStateDiscovery()`:
  ```mql5
  if(g_stateDiscoveryTime[state] != 0)
     Print("ERRO: Tentativa de redescobrir estado ", state);
  ```
- Executar robô por 1 hora
- Verificar que mensagem NUNCA aparece

**Status**: ☐ Passou ☐ Falhou

---

### INT-3: Compatibilidade com Arquivos Antigos

**Verificação**: Não quebra ao carregar arquivo sem discovery info
- Usar arquivo `state_memory.bin` de versão anterior
- Iniciar robô
- Verificar que não há erros

**Resultado Esperado**:
```
✅ Estados carregados da memória persistente
📊 Estados ativos: X
📊 Estados descobertos: X  ← Assumiu activeCount como descobertos
```

**Status**: ☐ Passou ☐ Falhou

---

## Checklist de Validação Final

- [ ] Todos os testes passaram
- [ ] Nenhum erro no Expert Journal
- [ ] HUD atualiza corretamente
- [ ] Dados persistem entre sessões
- [ ] Indicador visual funciona
- [ ] Exportação inclui informações corretas
- [ ] Sem vazamentos de memória (executar por 24h)
- [ ] Compatível com versões anteriores

## Notas de Execução

**Data do teste**: _______________

**Versão testada**: v307F

**Observações**:
_______________________________________________________
_______________________________________________________
_______________________________________________________
_______________________________________________________

**Problemas encontrados**:
_______________________________________________________
_______________________________________________________
_______________________________________________________
_______________________________________________________

**Assinatura**: _______________
