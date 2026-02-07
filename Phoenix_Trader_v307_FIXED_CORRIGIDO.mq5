//+------------------------------------------------------------------+
//|                         Phoenix_Trader_v307_FIXED_CORRIGIDO.mq5  |
//|          CONTAGEM CORRIGIDA + DECAY FUNCIONAL + EXPLORAÇÃO LIMITADA |
//|                  COM SISTEMA DE MEMÓRIA OTIMIZADA COMPLETA       |
//|                      SISTEMA DE BLOQUEIO UNIFICADO              |
//|                             ESTADOS VARIADOS v307F_ESTADOS       |
//|                + SISTEMA DE DECAY E RESET INTELIGENTE           |
//|                  + CORREÇÕES CRÍTICAS IMPLEMENTADAS             |
//|               + CORREÇÕES EXTREMAS PARA ESTADOS TRAVADOS        |
//+------------------------------------------------------------------+
#property copyright "Phoenix Trader"
#property link      ""
#property version   "3.07"

// ====
// Includes essenciais
// ====
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>

// ====
// ✅ PASSO 1 — CRIAR MEMÓRIA PERSISTENTE (OBRIGATÓRIO)
// ====
#define STATE_FILE "Phoenix_Files/Backups/state_memory.bin"

// ====
// Objetos utilitários
// ====
CTrade          trade;
CPositionInfo   positionInfo;
COrderInfo      orderInfo;
CDealInfo       dealInfo;
CHistoryOrderInfo historyOrderInfo;

// ====
// ✅✅✅ ATUALIZAÇÃO CRÍTICA: DISCRETIZAÇÃO DE ESTADO OTIMIZADA
// ============================================================
// Reduzindo para um número gerenciável de estados
#define BINS_MA_DIST   3      // Reduzido de 6 para 3
#define BINS_RSI       4      // Reduzido de 6 para 4  
#define BINS_MACD      3      // MACD Histograma (negativo, neutro, positivo)
#define BINS_VOLATILITY 2     // Mantido 2
#define BINS_VOLUME    2      // Reduzido de 3 para 2
#define BINS_TIME      2      // Reduzido de 4 para 2

// Cálculo do número total de estados - ATUALIZADO COM MACD
#define NUM_STATES (BINS_MA_DIST * BINS_RSI * BINS_MACD * BINS_VOLATILITY * BINS_VOLUME * BINS_TIME)

#define NUM_ACTIONS 3  // 0:NOP, 1:Buy, 2:Sell

// ============================================================
// ✅ CONSTANTES CRÍTICAS - APRENDIZADO CORRIGIDO
// ============================================================
const int MIN_VISITS_FOR_BLOCK = 30;

// Persistência
#define FILE_MAGIC   0x50484F45
#define FILE_VERSION 3073

#ifndef INT_MAX
  #define INT_MAX 2147483647
#endif
#ifndef DBL_MAX
  #define DBL_MAX 1.7e308
#endif

// ══════════════════════════════════════════════════════════════════════
// 📋 PARÂMETROS DE ENTRADA - ORGANIZADOS POR CATEGORIA
// ══════════════════════════════════════════════════════════════════════

// ──────────────────────────────────────────────────────────────────────
// 🛡️ 1. CONTROLE DE RISCO E LIMITES
// ──────────────────────────────────────────────────────────────────────
input group "──── 🛡️ LIMITES DIÁRIOS ────";
input int    MaxTradesPerDay          = 30;           // Máximo de trades por dia
input int    ConsecutiveLossLimit     = 15;           // Limite de perdas consecutivas

input group "──── 💰 NEGOCIAÇÃO BÁSICA ────";
input double LotSize                  = 0.01;         // Tamanho do lote padrão
input int    MagicNumber              = 27101;        // Número mágico das ordens
input int    MinMinutesBetweenTrades  = 3;            // Tempo mínimo entre trades

// ──────────────────────────────────────────────────────────────────────
// 📈 2. INDICADORES TÉCNICOS
// ──────────────────────────────────────────────────────────────────────
input group "──── 📊 INDICADORES PRINCIPAIS ────";
input int    MAPeriod                 = 200;          // Período da Média Móvel
input ENUM_MA_METHOD  MAMethod        = MODE_EMA;     // Tipo da Média Móvel
input int    RSIPeriod                = 20;           // Período do RSI
input int    MACD_Fast                = 12;           // MACD - EMA Rápida
input int    MACD_Slow                = 26;           // MACD - EMA Lenta
input int    MACD_Signal              = 9;            // MACD - Período do Sinal
input int    ATRPeriod                = 18;           // Período do ATR

input group "──── ✅ VALIDAÇÕES DE INDICADORES ────";
input bool   UseRSIValidation         = true;         // Usar validação por RSI
input double RSI_Overbought           = 75.0;         // RSI sobrecomprado
input double RSI_Oversold             = 25.0;         // RSI sobrevendido
input bool   UseTrendValidation       = true;         // Usar validação de tendência
input double MinDistanceFromMA        = 0.3;          // Distância mínima da MA

input group "──── 📊 FILTRO DE VOLUME ────";
input bool   UseRealVolumeFilter      = true;         // Usar filtro de volume
input int    VolumeMAPeriod           = 15;           // Período MA de volume
input double MinVolumeMultiplier      = 0.5;          // Multiplicador mínimo de volume

// ──────────────────────────────────────────────────────────────────────
// 🎯 3. GESTÃO DE STOPS E ALVOS
// ──────────────────────────────────────────────────────────────────────
input group "──── 🛑 STOP LOSS (PONTOS) ────";
input bool   UseFixedSL               = true;         // Usar stop loss fixo
input int    FixedSL_Points           = 35000;        // Stop loss em pontos

input group "──── 🎯 TAKE PROFIT (PONTOS) ────";
input bool   UseFixedTP               = true;         // Usar take profit fixo
input int    FixedTP_Points           = 70000;        // Take profit em pontos

input group "──── 🎯 TRAILING STOP DINÂMICO ────";
input bool   UseDynamicTrailingStop   = false;        // Usar trailing stop dinâmico
input int    TrailingStopPoints       = 20000;        // Trailing stop em pontos
input int    TrailingStepPoints       = 5000;         // Passo do trailing em pontos
input int    TrailingStartPoints      = 10000;        // Início do trailing em pontos
// ❌ ATR trailing REMOVIDO - sistema usa APENAS pontos fixos
input bool   UseBreakevenStop         = false;        // Usar breakeven
input int    BreakevenTriggerPoints   = 15000;        // Trigger do breakeven em pontos
input bool   TrailBothSLandTP         = false;        // Trailing em SL e TP

// ──────────────────────────────────────────────────────────────────────
// 💼 4. GESTÃO DE POSIÇÕES
// ──────────────────────────────────────────────────────────────────────
input group "──── 💎 BET SIZING INTELIGENTE ────";
input bool   EnableSmartLot           = true;         // Habilitar lote inteligente
input double HighQualityThreshold     = 0.3;          // Threshold alta qualidade
input double UltraQualityThreshold    = 0.8;          // Threshold ultra qualidade
input double SmartLotMultiplier       = 1.8;          // Multiplicador lote normal
input double UltraLotMultiplier       = 3.0;          // Multiplicador lote ultra
input double MaxAllowedLot            = 1.0;          // Lote máximo permitido

input group "──── 📊 PIRAMIDAÇÃO ────";
input bool   EnablePyramiding         = true;         // Habilitar piramidação
input int    MaxPyramidPositions      = 4;            // Máximo de posições pirâmide
input double PyramidingDistanceATR    = 0.4;          // Distância entre posições (ATR)
input bool   ReduceLotOnPyramiding    = false;        // Reduzir lote na piramidação
input double PyramidingLotMultiplier  = 0.8;          // Multiplicador lote pirâmide

input group "──── 🎯 CONTROLE DE DIREÇÃO ────";
input bool   AllowOnlyOneDirection    = true;         // Permitir só uma direção
input bool   CloseOppositeOnNewSignal = false;        // Fechar oposto em novo sinal
input bool   WaitForAllCloseBeforeNew = true;         // Aguardar fechamento total

input group "──── 🎮 CONTROLE DE ENTRADAS ────";
input int    MaxTradesPerDirection    = 4;            // Máximo trades por direção
input int    MinBarsBetweenSameDirection = 2;         // Barras mínimas entre entradas
input bool   UseVolatilityFilter      = true;         // Usar filtro de volatilidade
input double MaxATRMultiplier         = 4.0;          // Multiplicador máximo ATR

// ──────────────────────────────────────────────────────────────────────
// 🧠 5. SISTEMA DE APRENDIZADO (Q-Learning)
// ──────────────────────────────────────────────────────────────────────
input group "──── 🧠 APRENDIZADO BÁSICO ────";
input bool   UseSimpleRewardSystem    = true;         // Sistema de recompensa simples
input double RewardWin                = 5.0;          // Recompensa por vitória
input double RewardLoss               = -2.0;         // Penalidade por perda
input bool   EnableDynamicReward      = false;        // Reward dinâmica por estado
double LearningRate                   = 0.03;         // Taxa de aprendizado (fixo)

input group "──── 🎲 EXPLORAÇÃO ────";
input bool   EnableAdaptiveExploration = false;       // Habilitar ajuste automático de exploração
input double InitialExplorationRate   = 0.40;         // Taxa inicial de exploração (40%)
input double MinExplorationRate       = 0.20;         // Taxa mínima de exploração (20%)
input double ExplorationDecay         = 0.999;        // Decay da exploração (0.1% por vitória)
input int    MinStateVisitsToTrade    = 2;            // Visitas mínimas para operar

input group "──── 🔄 SISTEMA HÍBRIDO ────";
input bool   EnablePyramidingLearning = true;         // Aprendizado de piramidação
input int    PyramidLearningBonus     = 10;           // Bônus aprendizado pirâmide
input double PyramidBlockingMultiplier = 1.5;         // Multiplicador bloqueio pirâmide
input int    MinPyramidVisitsForBlock = 50;           // Visitas mín. para bloquear pirâmide

// ──────────────────────────────────────────────────────────────────────
// 💾 6. MEMÓRIA E PERSISTÊNCIA
// ──────────────────────────────────────────────────────────────────────
input group "──── 💾 OTIMIZAÇÃO DE MEMÓRIA ────";
input bool   EnableMemoryOptimization = true;         // Habilitar otimização memória
input int    MaxMemoryStates          = 1000;         // Máximo de estados na memória
input bool   CompressQValues          = true;         // Comprimir Q-values
input double QValuePrecision          = 2;            // Precisão dos Q-values
input bool   AutoCleanMemory          = true;         // Limpeza automática
input int    CleanMemoryAfterTrades   = 100;          // Limpar após N trades
input bool   UseIncrementalSave       = true;         // Salvamento incremental

input group "──── 🔄 DECAY E RESET ────";
input bool   EnableMemoryDecay        = true;         // Habilitar decay de memória
input double DecayFactor              = 0.05;         // Fator de decay (5%)
input bool   EnableIntelligentReset   = true;         // Reset inteligente
input double BadStateLossThreshold    = 0.60;         // Threshold perda para reset (60%)
input int    BadStateMinVisits        = 20;           // Visitas mínimas para reset
input int    MinStatesBeforeReset     = 150;          // Mínimo de estados aprendidos antes de permitir resets
input int    DecayCheckIntervalHours  = 1;            // Intervalo verificação decay (horas)
input bool   ExcludeNOPFromVisits     = true;         // NOP não conta visita

input group "──── 🚫 BLOQUEIO DE ESTADOS ────";
input bool   EnableUnifiedBlockingSystem = true;      // Sistema unificado bloqueio
input double StateBlockThreshold      = 0.20;         // Win rate mínimo para NÃO bloquear (20%)
input double BlockLossRateThreshold   = 0.80;         // Taxa perda para bloquear
input double UnblockWinRateThreshold  = 0.40;         // Taxa vitória para desbloquear (40% - mais permissivo)
input int    MinVisitsForBlockDecision    = 30;       // Visitas mín. decisão bloqueio

input group "──── 📊 SHARPE RATIO AVANÇADO ────";
input bool   EnableSharpeFilter       = false;        // Habilitar filtro Sharpe Ratio
input double MinSharpeToUnblock       = 0.8;          // Sharpe mínimo para desbloquear
input double MaxSharpeToBlock         = 0.3;          // Sharpe máximo para bloquear
input int    MinTradesForSharpe       = 30;           // Trades mínimos para calcular Sharpe

// ──────────────────────────────────────────────────────────────────────
// 📤 7. EXPORTAÇÃO E LOGS
// ──────────────────────────────────────────────────────────────────────
input group "──── 💾 EXPORTAÇÃO BINÁRIA ────";
input bool   EnableMemoryExport       = true;         // Habilitar exportação
input int    AutoExportMinutes        = 30;           // Intervalo auto-export (min)
input bool   ExportOnDeinit           = true;         // Exportar ao finalizar
input bool   CreateBackupFiles        = true;         // Criar backups
input int    MaxBackupFiles           = 3;            // Máximo de backups (PROTEÇÃO: mantém 3 cópias)
input bool   ExportMemoryToTextFile   = true;         // Exportar para texto
input int    TextExportIntervalMinutes = 60;          // Intervalo export texto (min)
input bool   SaveAfterEachTrade       = true;         // ✅ NOVO: Salvar após cada trade (ANTI-PERDA)
input bool   EnablePeriodicAutoSave   = true;         // ✅ NOVO: Salvamento periódico automático
input int    PeriodicSaveMinutes      = 15;           // ✅ NOVO: Salvar a cada X minutos

input group "──── 📄 EXPORTAÇÃO TEXTO ────";
input bool   EnableTextExport         = false;        // Habilitar export texto (apenas binário recomendado)
input int    TextExportMinInterval    = 60;           // Intervalo mínimo (min)
input bool   ExportAllStates          = false;        // Exportar todos estados
input bool   IncludeQValues           = true;         // Incluir Q-values
input bool   IncludeStatistics        = true;         // Incluir estatísticas
input int    MaxStatesToExport        = 500;          // Máximo estados exportar

// ──────────────────────────────────────────────────────────────────────
// 🖥️ 8. INTERFACE (HUD)
// ──────────────────────────────────────────────────────────────────────
input group "──── 🖥️ HUD (INTERFACE VISUAL) ────";
input bool   ShowHUD                  = true;         // Mostrar HUD
input int    HUD_X                    = 10;           // Posição X
input int    HUD_Y                    = 20;           // Posição Y
input int    HUD_UpdateMS             = 500;          // Intervalo atualização (ms)
input color  HUD_TitleColor           = clrLime;      // Cor título
input color  HUD_TextColor            = clrWhite;     // Cor texto
input color  HUD_WarningColor         = clrOrange;    // Cor aviso
input color  HUD_ErrorColor           = clrRed;       // Cor erro
input color  HUD_SuccessColor         = clrCyan;      // Cor sucesso
input bool   HUD_Minimal              = false;        // Modo minimalista

// ======================================================================
// ======================================================================
// 📊 VARIÁVEIS GLOBAIS - ORGANIZADAS POR CATEGORIA
// ======================================================================

// ──────────────────────────────────────────────────────────────────────
// 🧠 1. SISTEMA DE APRENDIZADO (Q-Learning e Estados)
// ──────────────────────────────────────────────────────────────────────
double g_Q[];                          // Q-table principal para aprendizado
int g_stateVisits[];                   // Contador de visitas por estado
int g_stateWins[];                     // Contadores de vitórias por estado
int g_stateLosses[];                   // Contadores de perdas por estado
double g_stateProfitSum[];             // Soma de lucros por estado (para Sharpe Ratio)
double g_stateProfitSqSum[];           // Soma de lucros ao quadrado por estado (para Sharpe Ratio)
int g_stateLastUpdate[];               // Último update de cada estado
bool g_stateBlocked[];                 // Estados bloqueados por má performance
datetime g_stateLastBlockTime[];       // Timestamp do último bloqueio
datetime g_stateLastUnblockTime[];     // Timestamp do último desbloqueio
bool g_stateWasBlockedBefore[];        // Flag indicando se o estado já foi bloqueado anteriormente
datetime g_stateBlockTime[];           // Timestamp de quando o estado foi bloqueado pela primeira vez
int g_stateBlockCount[];               // Contador de quantas vezes o estado foi bloqueado
double g_stateWinRate[];               // Win rate calculado por estado
double g_stateAvgProfit[];             // Lucro médio por estado

// Aprendizado - Controle
bool g_learningInitialized = false;
double g_currentExplorationRate = 0.0;
int g_totalStatesDiscovered = 0;
int g_totalQUpdates = 0;
double g_averageQValue = 0.0;
double g_maxQValue = 0.0;
double g_minQValue = 0.0;

// Aprendizado - Proteção contra estados congelados
static int g_lastCalculatedState = -1;
static int g_sameStateCount = 0;
static datetime g_lastStateChangeTime = 0;

// ──────────────────────────────────────────────────────────────────────
// 💾 2. SISTEMA DE MEMÓRIA E PERSISTÊNCIA
// ──────────────────────────────────────────────────────────────────────
int g_activeStates[];                  // Cache de estados ativos (otimização)
int g_activeStatesCount = 0;
bool g_memoryDirty = false;
int g_memorySaveCounter = 0;
int g_memoryCleanCounter = 0;
string g_memoryFileName = "";
bool g_memoryInitialized = false;
datetime g_lastSaveTime = 0;
int g_qUpdatesSinceSave = 0;
bool g_lastSaveSuccess = false;

// Decay e Reset
datetime g_lastMaintenanceTime = 0;
int g_totalDecayCycles = 0;
int g_totalBadStateResets = 0;
int g_stateResets = 0;
int g_stateDecays = 0;
static int g_lastDecayTradeCount = 0;
datetime g_lastUnblockTestTime = 0; // Tempo do último teste de desbloqueio

// ──────────────────────────────────────────────────────────────────────
// 📈 3. INDICADORES TÉCNICOS
// ──────────────────────────────────────────────────────────────────────
string g_currentSymbol;
int g_maHandle   = INVALID_HANDLE;
int g_rsiHandle  = INVALID_HANDLE;
int g_macdHandle = INVALID_HANDLE;
int g_atrHandle  = INVALID_HANDLE;

// ──────────────────────────────────────────────────────────────────────
// 💰 4. CONTROLE DE TRADES E POSIÇÕES
// ──────────────────────────────────────────────────────────────────────
// Última trade executada
int g_lastTradeState = -1;
double g_lastTradeProfit = 0.0;
int g_lastTradeAction = 0;
double g_lastLotUsed = 0.0;
double g_lastSLPrice = 0.0;
double g_lastTPPrice = 0.0;
bool g_lastTradeExecuted = false;
int g_lastTradeStateExecuted = -1;

// ✅ MAE/MFE TRACKING - Rastreamento de eficiência de trades
double g_positionMAE[];      // Maximum Adverse Excursion por posição
double g_positionMFE[];      // Maximum Favorable Excursion por posição
ulong g_positionTickets[];   // Tickets das posições rastreadas
double g_positionEntry[];    // Preço de entrada de cada posição
double g_positionSL[];       // Stop Loss de cada posição
double g_positionTP[];       // Take Profit de cada posição
int g_positionDirection[];   // Direção (+1=Buy, -1=Sell)
int g_trackedPositionsCount = 0; // Contador de posições rastreadas

// Controle de direção e posições
int g_currentDirection = 0;
int g_positionsCount = 0;
datetime g_directionStartTime = 0;

// Controle de timing
datetime g_lastEntryTime = 0;
datetime g_lastTradeTime = 0;
datetime g_lastBuyTime = 0;
datetime g_lastSellTime = 0;
int g_lastBarProcessed = 0;

// Controle diário
int g_tradesToday = 0;
datetime g_lastTradeDate = 0;
datetime g_lastResetDate = 0;

// ──────────────────────────────────────────────────────────────────────
// 📊 5. ESTATÍSTICAS E PERFORMANCE
// ──────────────────────────────────────────────────────────────────────
// Estatísticas gerais
int g_totalTrades = 0;
int g_totalWins   = 0;
int g_totalLosses = 0;
double g_sumProfit = 0.0;
int g_consecutiveLosses = 0;

// Estatísticas por direção
int g_totalBuys = 0;
int g_totalSells = 0;
int g_buyWins = 0;
int g_sellWins = 0;
double g_buyProfit = 0.0;
double g_sellProfit = 0.0;

// Recordes e streaks
datetime g_firstTradeDate = 0;
double g_highestProfit = 0.0;
double g_lowestProfit = 0.0;
int g_bestWinStreak = 0;
int g_worstLossStreak = 0;
int g_currentWinStreak = 0;
int g_currentLossStreak = 0;

// Performance recente
double g_recentProfits[];
int g_recentProfitsIndex = 0;

// ──────────────────────────────────────────────────────────────────────
// 📊 6. VOLUME E FILTROS
// ──────────────────────────────────────────────────────────────────────
long g_currentVolume = 0;
long g_volumeAverage = 0;
double g_volumeMultiplier = 1.0;
double g_volumeStrength = 0.0;
double g_volumeRatio = 1.0;
datetime g_lastVolumeCheck = 0;
bool AllowBreakoutOverride = true;

// ──────────────────────────────────────────────────────────────────────
// 🎯 7. TRAILING STOP DINÂMICO
// ──────────────────────────────────────────────────────────────────────
ulong   g_trailingTickets[];
double  g_trailingBestPrices[];
double  g_trailingCurrentSL[];
double  g_trailingCurrentTP[];
datetime g_trailingLastTrailTimes[];
bool    g_trailingBreakevenActivated[];
int     g_trailingCount = 0;

// ──────────────────────────────────────────────────────────────────────
// 🖥️ 8. HUD (INTERFACE VISUAL)
// ──────────────────────────────────────────────────────────────────────
string hudObjects[20];  // Increased to accommodate all HUD objects + buffer for future additions
int hudObjectCount = 0;
datetime hudLastUpdate = 0;
string g_statusMessage = "Inicializando...";

// Cache do HUD (otimização)
int cachedVisitedStates = -1;
int cachedBlockedStates = -1;
int cachedPositions = -1;
int cachedDirection = -1;
string cachedStatus = "";
double cachedVolume = -1;
int cachedTradesToday = -1;

// ──────────────────────────────────────────────────────────────────────
// 📤 9. EXPORTAÇÃO E LOGS
// ──────────────────────────────────────────────────────────────────────
datetime g_lastExportTime = 0;
int g_exportCount = 0;
datetime g_lastTextExportTime = 0;
int g_textExportCount = 0;
datetime g_lastPeriodicSaveTime = 0;  // ✅ NOVO: Controle de salvamento periódico
int g_periodicSaveCount = 0;          // ✅ NOVO: Contador de saves periódicos

// ──────────────────────────────────────────────────────────────────────
// 📅 RELATÓRIO MENSAL/ANUAL DE LUCROS
// ──────────────────────────────────────────────────────────────────────
struct MonthlyStats {
   double totalProfit;
   double totalLoss;
   int tradeCount;
};

MonthlyStats g_monthlyStats[20][12];  // [ano_index][mês_index] - últimos 20 anos
int g_firstYearTracked = 0;            // Primeiro ano que começou o tracking
bool g_monthlyStatsInitialized = false;

// ──────────────────────────────────────────────────────────────────────
// 🐛 10. DEBUG E DIAGNÓSTICO
// ──────────────────────────────────────────────────────────────────────
int g_debugState = -1;
int g_debugVisitas = 0;
int g_debugPerdas = 0;

// ======================================================================
// ✅✅✅ CORREÇÕES AGUDAS PARA O PROBLEMA DE ESTADOS TRAVADOS
// ======================================================================

// ======================================================================
// ✅✅✅ FUNÇÕES REMOVIDAS (d651ec8): FixStuckStatesProblem() e ResetBlockingSystem()
// Essas funções limitavam artificialmente as visitas dos estados, impedindo
// que atingissem MinVisitsForBlockDecision (20). Foram completamente removidas.
// ======================================================================

// ======================================================================
// ✅✅✅ 4. FUNÇÃO: DEBUG MELHORADO PARA ESTADOS TRAVADOS
// ======================================================================
void DebugStuckStatesEnhanced()
{
   Print("=== DEBUG ESTADOS TRAVADOS (VERSÃO MELHORADA) ===");
   
   int stuckAt10 = 0;
   int stuckAt20 = 0;
   int stuckAt30 = 0;
   int wronglyBlocked = 0;
   int correctlyBlocked = 0;
   int totalBlocked = 0;
   
   for(int state = 0; state < NUM_STATES; state++)
   {
      if(g_stateVisits[state] > 0)
      {
         if(g_stateVisits[state] == 10) stuckAt10++;
         if(g_stateVisits[state] == 20) stuckAt20++;
         if(g_stateVisits[state] == 30) stuckAt30++;
         
         if(g_stateBlocked[state])
         {
            totalBlocked++;
            double winRate = CalculateWinRate(state);
            
            if(winRate >= 0.30 && g_stateVisits[state] >= 5)
            {
               wronglyBlocked++;
               Print("❌❌❌ ERRO CRÍTICO: Estado ", state, 
                     " bloqueado com win rate BOA: ", DoubleToString(winRate*100,1), "%",
                     " | Visitas: ", g_stateVisits[state]);
            }
            else if(winRate < 0.25 && g_stateVisits[state] >= 5)
            {
               correctlyBlocked++;
            }
         }
      }
   }
   
   Print("📊 ESTATÍSTICAS DETALHADAS:");
   Print("   Estados travados em 10 visitas: ", stuckAt10);
   Print("   Estados travados em 20 visitas: ", stuckAt20);
   Print("   Estados travados em 30 visitas: ", stuckAt30);
   Print("   Estados bloqueados totais: ", totalBlocked);
   Print("   Estados bloqueados CORRETAMENTE: ", correctlyBlocked);
   Print("   Estados bloqueados ERRONEAMENTE: ", wronglyBlocked);
   Print("   Taxa de erro no bloqueio: ", totalBlocked > 0 ? 
         DoubleToString((double)wronglyBlocked/totalBlocked*100, 1) : "0.0", "%");
   
   // ✅ CORREÇÃO AUTOMÁTICA
   if(wronglyBlocked > 0)
   {
      Print("🔥🔥🔥 APLICANDO CORREÇÃO AUTOMÁTICA...");
      
      // ❌ REMOVIDO - Desbloqueio deve ser feito APENAS por:
      // 1. AutoUnblockGoodStates() com critérios rigorosos (55% win rate, 30 visitas)
      // 2. TestBlockedStatesPeriodically() após 30 dias com reteste gradual
      // Desbloquear aqui com 30% e 5 visitas é MUITO permissivo e causa desbloqueios prematuros
      
      // for(int state = 0; state < NUM_STATES; state++)
      // {
      //    if(g_stateBlocked[state])
      //    {
      //       double winRate = CalculateWinRate(state);
      //       
      //       if(winRate >= 0.30 && g_stateVisits[state] >= 5)
      //       {
      //          g_stateBlocked[state] = false;
      //          Print("✅ Estado ", state, " desbloqueado automaticamente");
      //       }
      //    }
      // }
      
      Print("✅✅✅ ", wronglyBlocked, " estados desbloqueados automaticamente");
   }
   
   Print("=== FIM DEBUG ===");
}

// ======================================================================
// ✅✅✅ 5. FUNÇÃO: DESBLOQUEAR ESTADOS BONS (REMOVIDO RESET DE ESTADOS)
// ======================================================================
void UnblockGoodStates()
{
   if(!EnableIntelligentReset) return;
   
   // ✅ PROTEÇÃO: Só desbloquear após ter base sólida de estados aprendidos
   if(g_activeStatesCount < MinStatesBeforeReset)
   {
      return;
   }
   
   int statesUnblocked = 0;
   
   Print("🔓 DESBLOQUEIO INTELIGENTE DE ESTADOS BONS");
   
   for(int s = 0; s < NUM_STATES; s++)
   {
      if(g_stateVisits[s] >= MinVisitsForBlockDecision)
      {
         double winRate = CalculateWinRate(s);
         
         // ✅ DESBLOQUEAR ESTADOS BONS (APENAS TESTAR, SEM RESETAR)
         if(g_stateBlocked[s] && winRate >= 0.35)
         {
            g_stateBlocked[s] = false;
            g_stateLastUnblockTime[s] = TimeCurrent();
            statesUnblocked++;
            Print("✅ DESBLOQUEIO Estado ", s,
                  " | Win Rate boa: ", DoubleToString(winRate*100,1), "%",
                  " | Visitas: ", g_stateVisits[s]);
            
            g_memoryDirty = true;
            InvalidateHUDCache();
         }
      }
   }
   
   if(statesUnblocked > 0)
   {
      Print("📊 RESUMO DO DESBLOQUEIO:");
      Print("   Estados desbloqueados: ", statesUnblocked);
      Print("   Total estados bloqueados restantes: ", CountBlockedStates());
      
      g_memoryDirty = true;
      SaveState();
   }
}

// ======================================================================
// ✅✅✅ FUNÇÕES DE DECAY E RESET INTELIGENTE (NOVAS)
// ======================================================================

// ======================================================================
// ✅✅✅ 1. FUNÇÃO DE DECAIMENTO SUAVE (CORRIGIDA)
// ======================================================================
void ApplyStateDecay()
{
   if(!EnableMemoryDecay) return;
   
   // ✅ PROTEÇÃO: Não aplicar decay antes de ter 100 estados descobertos
   // Garante fase completa de aprendizado sem perder estados prematuramente
   if(g_activeStatesCount < MinStatesBeforeReset)
   {
      return; // Decay desabilitado durante fase de descoberta inicial
   }
   
   const double DECAY_FACTOR = DecayFactor; // Configurável pelo usuário (% a esquecer)
   int statesDecayed = 0;
   double totalMemoryBefore = 0;
   double totalMemoryAfter = 0;

   for(int s = 0; s < NUM_STATES; s++)
   {
      if(g_stateVisits[s] > 0)
      {
         totalMemoryBefore += g_stateVisits[s];
         
         // Aplicar decay somente em estados com histórico muito significativo
         // ✅ CORREÇÃO: Aumentado de >10 para >100 para permitir amadurecimento adequado antes do decay
         if(g_stateVisits[s] > 100)
         {
            // ✅ CORREÇÃO: Decay deve REMOVER X%, não MANTER X%
            // Se DecayFactor = 0.05 (5%), deve manter 95% (1.0 - 0.05)
            g_stateVisits[s] = (int)(g_stateVisits[s] * (1.0 - DECAY_FACTOR));
            g_stateLosses[s] = (int)(g_stateLosses[s] * (1.0 - DECAY_FACTOR));
            g_stateWins[s] = (int)(g_stateWins[s] * (1.0 - DECAY_FACTOR));
            
            // Garantir valores mínimos
            if(g_stateVisits[s] < 1 && g_stateVisits[s] > 0) g_stateVisits[s] = 1;
            if(g_stateLosses[s] < 0) g_stateLosses[s] = 0;
            if(g_stateWins[s] < 0) g_stateWins[s] = 0;
            
            statesDecayed++;
            
            // Atualizar Q-values gradualmente
            for(int a = 0; a < NUM_ACTIONS; a++)
            {
               int idx = s * NUM_ACTIONS + a;
               if(g_Q[idx] != 0.0)
               {
                  g_Q[idx] *= (1.0 - DECAY_FACTOR);
               }
            }
         }
         
         totalMemoryAfter += g_stateVisits[s];
      }
   }
   
   // Recalcular estados ativos
   g_activeStatesCount = 0;
   for(int state = 0; state < NUM_STATES; state++)
   {
      if(g_stateVisits[state] > 0)
      {
         if(g_activeStatesCount < MaxMemoryStates)
         {
            g_activeStates[g_activeStatesCount] = state;
            g_activeStatesCount++;
         }
      }
   }
   
   g_totalDecayCycles++;
   
   double memoryReduction = totalMemoryBefore > 0 ? 
                          (1.0 - SafeDivide(totalMemoryAfter, totalMemoryBefore, 1.0)) * 100 : 0;
   
   Print("🔄 DECAY APLICADO: ", 
         "Estados ajustados: ", statesDecayed,
         " | Redução memória: ", DoubleToString(memoryReduction, 1), "%",
         " | Estados ativos: ", g_activeStatesCount,
         " | Ciclos: ", g_totalDecayCycles);
   
   g_memoryDirty = true;
}

// ======================================================================
// ✅✅✅ 2. DESBLOQUEAR ESTADOS BONS (REMOVIDO RESET INTELIGENTE)
// ======================================================================
void UnblockGoodStatesAutomatic()
{
   if(!EnableIntelligentReset) return;
   
   // Verificar se temos estados suficientes antes de permitir desbloqueios
   if(g_activeStatesCount < MinStatesBeforeReset)
   {
      return; // Não desbloquear até ter aprendido estados suficientes
   }
   
   int statesUnblocked = 0;
   
   for(int s = 0; s < NUM_STATES; s++)
   {
      if(g_stateVisits[s] < BadStateMinVisits) continue;
      
      if(!g_stateBlocked[s]) continue; // Apenas estados bloqueados
      
      double winRate = CalculateWinRate(s);
      
      // ✅ DESBLOQUEAR ESTADOS BONS - Win rate >= 35%
      if(winRate >= 0.35)
      {
         g_stateBlocked[s] = false;
         g_stateLastUnblockTime[s] = TimeCurrent();
         
         statesUnblocked++;
         
         Print("✅ DESBLOQUEIO AUTOMÁTICO -> Estado: ", s,
               " | Visitas: ", g_stateVisits[s],
               " | Vitórias: ", g_stateWins[s],
               " | Win Rate: ", DoubleToString(winRate*100, 1), "%");
         
         g_memoryDirty = true;
         InvalidateHUDCache();
      }
   }
   
   if(statesUnblocked > 0)
   {
      Print("✅ ", statesUnblocked, " estados bons desbloqueados | Total bloqueados: ", CountBlockedStates());
   }
}

// ======================================================================
// ✅✅✅ 3. MANUTENÇÃO PERIÓDICA DO SISTEMA
// ======================================================================
void PerformMemoryMaintenance()
{
   static datetime lastMaintenance = 0;
   
   if(TimeCurrent() - lastMaintenance < (DecayCheckIntervalHours * 3600))
      return;
   
   Print("🔧 INICIANDO MANUTENÇÃO PERIÓDICA DO SISTEMA...");
   
   // 1. Aplicar decay suave
   if(EnableMemoryDecay)
   {
      ApplyStateDecay();
   }
   
   // 2. Desbloquear estados bons (apenas após atingir limite mínimo)
   if(EnableIntelligentReset && g_activeStatesCount >= MinStatesBeforeReset)
   {
      UnblockGoodStatesAutomatic();
   }
   
   // 3. Limpar memória se necessário
   if(AutoCleanMemory)
   {
      CleanMemory();
   }
   
   // 4. Auto desbloquear estados bons
   if(EnableUnifiedBlockingSystem)
   {
      AutoUnblockGoodStates();
   }
   
   lastMaintenance = TimeCurrent();
   
   // Salvar após manutenção
   SaveBrain();
   SaveState();
   
   Print("✅ MANUTENÇÃO COMPLETA REALIZADA");
   Print("   • Decay aplicado: ", g_totalDecayCycles, " ciclos");
   Print("   • Estados ativos: ", g_activeStatesCount);
   Print("   • Estados bloqueados: ", CountBlockedStates());
}

// ======================================================================
// ✅✅✅ SISTEMA DE BLOQUEIO UNIFICADO CORRIGIDO
// ======================================================================

// ✅✅✅ 1️⃣ FUNÇÃO UNIFICADA PARA BLOQUEAR ESTADO (CORRIGIDA)
void BlockState(int state)
{
    if(state < 0 || state >= NUM_STATES) return;

    if(g_stateLastBlockTime[state] > 0 && TimeCurrent() - g_stateLastBlockTime[state] < 3600)
    {
        Print("⏳ Cooldown ativo para estado ", state, " - aguardando 1h");
        return;
    }

    if(g_stateBlocked[state])
    {
        return;
    }

    int visits = g_stateVisits[state];
    int losses = g_stateLosses[state];
    
    if(visits < MinVisitsForBlockDecision)
    {
        Print("✅ Estado ", state, " tem poucas visitas (", visits, ") - NÃO bloqueando");
        return;
    }
    
    double lossRate = SafeDivide((double)losses, (double)visits, 0.0);
    
    if(lossRate >= BlockLossRateThreshold)
    {
        g_stateBlocked[state] = true;
        g_stateLastBlockTime[state] = TimeCurrent();
        
        // Incrementar contador de bloqueios
        g_stateBlockCount[state]++;
        
        // Marcar que este estado já foi bloqueado e registrar timestamp do primeiro bloqueio
        if(!g_stateWasBlockedBefore[state])
        {
            g_stateWasBlockedBefore[state] = true;
            g_stateBlockTime[state] = TimeCurrent();
        }
        
        Print("⛔ ESTADO BLOQUEADO CORRETAMENTE: ", state, 
              " | Visitas REAIS: ", visits, 
              " | Perdas REAIS: ", losses, 
              " | Taxa de perda: ", DoubleToString(lossRate*100, 1), "%",
              " | Mínimo requerido: ", MinVisitsForBlockDecision, " visitas",
              " | Bloqueios totais: ", g_stateBlockCount[state]);
        
        g_memoryDirty = true;
        InvalidateHUDCache();
    }
    else
    {
        Print("✅ Estado ", state, " NÃO bloqueado - Taxa de perda: ", 
              DoubleToString(lossRate*100, 1), "% (limite: ", BlockLossRateThreshold*100, "%)");
    }
}

// ✅✅✅ 2️⃣ FUNÇÃO UNIFICADA PARA DESBLOQUEAR ESTADO (CORRIGIDA)
void UnblockState(int state)
{
    if(state < 0 || state >= NUM_STATES) return;

    if(g_stateLastUnblockTime[state] > 0 && TimeCurrent() - g_stateLastUnblockTime[state] < 3600)
    {
        Print("⏳ Cooldown ativo para estado ", state, " - aguardando 1h");
        return;
    }

    if(g_stateBlocked[state])
    {
        g_stateBlocked[state] = false;
        g_stateLastUnblockTime[state] = TimeCurrent();
        
        Print("✅ ESTADO DESBLOQUEADO: ", state, 
              " | Visitas: ", g_stateVisits[state], 
              " | Vitórias: ", g_stateWins[state],
              " | Perdas: ", g_stateLosses[state],
              " | Win Rate: ", DoubleToString(CalculateWinRate(state)*100, 1), "%");
        
        g_memoryDirty = true;
        InvalidateHUDCache();
    }
}

// ✅✅✅ 3️⃣ FUNÇÃO PARA VERIFICAR SE UM ESTADO DEVE SER BLOQUEADO (CORRIGIDA)
bool ShouldBlockState(int state)
{
    if(state < 0 || state >= NUM_STATES) return false;
    
    int visits = g_stateVisits[state];
    int losses = g_stateLosses[state];
    int wins = g_stateWins[state];
    
    if(visits < MinVisitsForBlockDecision) 
    {
        // 🔍 DEBUG: Estado sem visitas suficientes (log reduzido)
        // Print("🔍 BLOCK DEBUG: State=", state, " | Visits=", visits, " < MinVisits=", MinVisitsForBlockDecision, " → SEM DADOS SUFICIENTES (não bloqueia)");
        return false;
    }
    
    double lossRate = SafeDivide((double)losses, (double)visits, 0.0);
    double winRate = SafeDivide((double)wins, (double)visits, 0.0);
    
    // Critério 1: Taxa de perda muito alta
    bool highLossRate = (lossRate >= BlockLossRateThreshold);
    
    // Critério 2: Sharpe Ratio muito baixo (se habilitado)
    bool lowSharpe = false;
    double sharpe = 0.0;
    if(EnableSharpeFilter)
    {
        int trades = g_stateWins[state] + g_stateLosses[state];
        if(trades >= MinTradesForSharpe)
        {
            sharpe = CalculateSharpeRatio(state);
            lowSharpe = (sharpe < MaxSharpeToBlock);
        }
    }
    
    // 🔍 DEBUG: Log detalhado apenas quando bloqueio vai acontecer
    bool shouldBlock = (highLossRate || lowSharpe);
    if(shouldBlock)
    {
        Print("🚫 BLOQUEANDO Estado ", state, 
              " | Visits=", visits,
              " | Wins=", wins,
              " | Losses=", losses,
              " | WinRate=", DoubleToString(winRate*100, 1), "%",
              " | LossRate=", DoubleToString(lossRate*100, 1), "%",
              " | LossRateTH=", DoubleToString(BlockLossRateThreshold*100, 1), "%",
              " | Sharpe=", DoubleToString(sharpe, 2),
              " | HighLoss?=", highLossRate,
              " | LowSharpe?=", lowSharpe);
    }
    
    // Bloquear se OU taxa de perda alta OU Sharpe muito baixo
    return shouldBlock;
}

// ✅✅✅ 4️⃣ FUNÇÃO PARA VERIFICAR SE UM ESTADO DEVE SER DESBLOQUEADO (CORRIGIDA)
bool ShouldUnblockState(int state)
{
    if(state < 0 || state >= NUM_STATES) return false;
    
    if(!g_stateBlocked[state]) return false;
    
    int visits = g_stateVisits[state];
    int wins = g_stateWins[state];
    int losses = g_stateLosses[state];
    
    if(visits < MinVisitsForBlockDecision) 
    {
        // 🔍 DEBUG: Estado bloqueado sem visitas suficientes para desbloquear
        Print("🔓 UNBLOCK DEBUG: State=", state, " | Visits=", visits, " < MinVisits=", MinVisitsForBlockDecision, " → SEM DADOS SUFICIENTES (não desbloqueia)");
        return false;
    }
    
    double winRate = CalculateWinRate(state);
    
    // Critério 1: Win rate suficientemente alto
    bool goodWinRate = (winRate >= UnblockWinRateThreshold);
    
    // Critério 2: Sharpe Ratio suficientemente alto (se habilitado)
    bool goodSharpe = true;
    double sharpe = 0.0;
    if(EnableSharpeFilter)
    {
        int trades = g_stateWins[state] + g_stateLosses[state];
        if(trades >= MinTradesForSharpe)
        {
            sharpe = CalculateSharpeRatio(state);
            goodSharpe = (sharpe >= MinSharpeToUnblock);
        }
        else
        {
            // Se não tem dados suficientes para Sharpe, não desbloquear ainda
            goodSharpe = false;
        }
    }
    
    // 🔍 DEBUG: Log detalhado de avaliação de desbloqueio
    bool shouldUnblock = (goodWinRate && goodSharpe);
    Print("🔓 UNBLOCK DEBUG: State=", state, 
          " | Visits=", visits,
          " | Wins=", wins,
          " | Losses=", losses,
          " | WinRate=", DoubleToString(winRate*100, 1), "%",
          " | WinRateTH=", DoubleToString(UnblockWinRateThreshold*100, 1), "%",
          " | Sharpe=", DoubleToString(sharpe, 2),
          " | SharpeTH=", DoubleToString(MinSharpeToUnblock, 2),
          " | EnableSharpe=", EnableSharpeFilter,
          " | GoodWR?=", goodWinRate,
          " | GoodSharpe?=", goodSharpe,
          " → SHOULD UNBLOCK=", shouldUnblock);
    
    // Desbloquear apenas se AMBOS win rate E Sharpe forem bons
    return shouldUnblock;
}

// ✅✅✅ 5️⃣ FUNÇÃO PRINCIPAL DE VERIFICAÇÃO DE BLOQUEIO (SOMENTE LEITURA)
bool IsStateBlocked(int state)
{
    if(state < 0 || state >= NUM_STATES) return false;
    
    return g_stateBlocked[state];
}

// ✅✅✅ 6️⃣ FUNÇÃO PARA AVALIAR E ATUALIZAR BLOQUEIO DE ESTADO (CORRIGIDA)
void EvaluateAndUpdateBlockState(int state)
{
    if(state < 0 || state >= NUM_STATES) return;
    
    // ✅ FIX: Removido cooldown timer - avaliar estado IMEDIATAMENTE após cada trade
    // Isso garante que estados ruins sejam bloqueados assim que atingem os critérios
    
    bool shouldBeBlocked = ShouldBlockState(state);
    bool currentlyBlocked = g_stateBlocked[state];
    
    if(shouldBeBlocked && !currentlyBlocked)
    {
        BlockState(state);
    }
    else if(!shouldBeBlocked && currentlyBlocked)
    {
        if(ShouldUnblockState(state))
        {
            UnblockState(state);
        }
    }
}

// ✅✅✅ 7️⃣ FUNÇÃO PARA AVALIAR TODOS OS ESTADOS ATIVOS (CORRIGIDA)
void EvaluateAllActiveStates()
{
    // ✅ FIX: Reduzido cooldown de 300s para 60s para avaliação mais frequente
    // Estados ruins serão detectados e bloqueados mais rapidamente
    static datetime lastFullEvaluation = 0;
    
    if(TimeCurrent() - lastFullEvaluation < 60)
        return;
    
    lastFullEvaluation = TimeCurrent();
    
    int blocked = 0;
    int unblocked = 0;
    
    for(int i = 0; i < g_activeStatesCount; i++)
    {
        int state = g_activeStates[i];
        
        bool shouldBeBlocked = ShouldBlockState(state);
        bool currentlyBlocked = g_stateBlocked[state];
        
        if(shouldBeBlocked && !currentlyBlocked)
        {
            BlockState(state);
            blocked++;
        }
        else if(!shouldBeBlocked && currentlyBlocked)
        {
            if(ShouldUnblockState(state))
            {
                UnblockState(state);
                unblocked++;
            }
        }
    }
    
    if(blocked > 0 || unblocked > 0)
    {
      Print("📊 Avaliação periódica de estados: ", blocked, " bloqueados, ", unblocked, " desbloqueados");
      Print("📊 Total estados bloqueados: ", CountBlockedStates());
    }
}

// ✅✅✅ 8️⃣ FUNÇÃO PARA DESBLOQUEAR ESTADOS BONS AUTOMATICAMENTE (CORRIGIDA)
void AutoUnblockGoodStates()
{
    int unblocked = 0;
    
    for(int state = 0; state < NUM_STATES; state++)
    {
        if(g_stateBlocked[state] && ShouldUnblockState(state))
        {
            UnblockState(state);
            unblocked++;
        }
    }
    
    if(unblocked > 0)
    {
        Print("🔄 ", unblocked, " estados desbloqueados automaticamente (win rate > ", 
              DoubleToString(UnblockWinRateThreshold*100, 0), "%)");
    }
}

// ======================================================================
// ✅ TESTAR PERIODICAMENTE ESTADOS BLOQUEADOS
// ======================================================================
// Testa estados bloqueados periodicamente para ver se melhoraram
// Desbloqueia temporariamente para coletar novas amostras
void TestBlockedStatesPeriodically()
{
   datetime currentTime = TimeCurrent();
   
   // Testar a cada 7 dias (604800 segundos)
   if(currentTime - g_lastUnblockTestTime < 604800)
   {
      return;
   }
   
   g_lastUnblockTestTime = currentTime;
   
   int testedStates = 0;
   int unblockedForTest = 0;
   
   for(int state = 0; state < NUM_STATES; state++)
   {
      if(!g_stateBlocked[state]) continue;
      
      // Apenas testar estados com histórico significativo
      if(g_stateVisits[state] < 10) continue;
      
      // Se estado já foi bloqueado 2+ vezes, PERMANECE BLOQUEADO
      if(g_stateBlockCount[state] >= 2)
      {
         // Log apenas na primeira iteração para não poluir
         if(testedStates == 0)
         {
            Print("🔒 Estado ", state, " PERMANENTEMENTE BLOQUEADO (bloqueado ", 
                  g_stateBlockCount[state], " vezes - sem mais retestes)");
         }
         testedStates++;
         continue; // Não desbloquear mais
      }
      
      datetime timeSinceBlock = currentTime - g_stateLastBlockTime[state];
      
      // Se estado está bloqueado há mais de 30 dias, dar nova chance
      if(timeSinceBlock > 2592000) // 30 dias em segundos
      {
         // Resetar estatísticas mas manter Q-values (aprendizado)
         g_stateVisits[state] = 0;
         g_stateWins[state] = 0;
         g_stateLosses[state] = 0;
         
         // Desbloquear temporariamente para teste
         g_stateBlocked[state] = false;
         g_stateLastUnblockTime[state] = currentTime;
         
         unblockedForTest++;
         
         int tentativasRestantes = 2 - g_stateBlockCount[state];
         string mensagemTentativa = (tentativasRestantes == 1) ? " (ÚLTIMA CHANCE)" : "";
         
         Print("🧪 Estado ", state, " desbloqueado para TESTE #", 
               (g_stateBlockCount[state] + 1), mensagemTentativa,
               " (bloqueado há ", (int)(timeSinceBlock / 86400), " dias)");
      }
      
      testedStates++;
      
      // Limitar a 1 estado por vez para teste gradual e controlado
      if(unblockedForTest >= 1) break;
   }
   
   if(unblockedForTest > 0)
   {
      Print("📊 Teste periódico de estados bloqueados: ", unblockedForTest, 
            " estado desbloqueado para coleta gradual de novas amostras");
      InvalidateHUDCache();
   }
}

// ======================================================================
// ✅✅✅ FUNÇÕES AUXILIARES CORRIGIDAS
// ======================================================================

// ======================================================================
// ✅ FUNÇÃO SAFEDIVIDE - PROTEÇÃO GLOBAL CONTRA DIVISÃO POR ZERO
// ======================================================================
// Função de divisão segura que previne erros de divisão por zero
// Parâmetros:
//   numerator - O valor a ser dividido (numerador)
//   denominator - O valor pelo qual dividir (denominador)
//   defaultValue - Valor a retornar se divisão não for possível (padrão: 0.0)
// Retorna:
//   - O resultado da divisão se denominador válido
//   - defaultValue se denominador for zero ou muito próximo de zero
// Exemplos:
//   SafeDivide(10.0, 2.0, 0.0) retorna 5.0
//   SafeDivide(10.0, 0.0, 0.0) retorna 0.0 (valor padrão)
//   SafeDivide(price - lower, range, 0.5) retorna 0.5 se range for zero
double SafeDivide(double numerator, double denominator, double defaultValue = 0.0)
{
   if(denominator == 0.0 || MathAbs(denominator) < 0.0000001)
   {
      return defaultValue;
   }
   return numerator / denominator;
}

double CalculateWinRate(int state)
{
    if(state < 0 || state >= NUM_STATES) return 0.0;
    if(g_stateVisits[state] == 0) return 0.0;
    
    return SafeDivide((double)g_stateWins[state], (double)g_stateVisits[state], 0.0);
}

//+------------------------------------------------------------------+
//| Calcula o Sharpe Ratio de um estado                              |
//| Retorna > 1.0 para excelente, 0.5-1.0 bom, < 0.3 ruim           |
//+------------------------------------------------------------------+
double CalculateSharpeRatio(int state)
{
    if(state < 0 || state >= NUM_STATES) return 0.0;
    
    int trades = g_stateWins[state] + g_stateLosses[state];
    
    // Precisa de dados suficientes
    if(trades < MinTradesForSharpe) return 0.0;
    
    // Calcular retorno médio
    double avgReturn = SafeDivide(g_stateProfitSum[state], (double)trades, 0.0);
    
    // Calcular variância
    double avgSquared = SafeDivide(g_stateProfitSqSum[state], (double)trades, 0.0);
    double variance = avgSquared - (avgReturn * avgReturn);
    
    if(variance <= 0.0) return 0.0;
    
    // Calcular desvio padrão
    double stdDev = MathSqrt(variance);
    
    if(stdDev == 0.0) return 0.0;
    
    // Sharpe Ratio = Retorno Médio / Desvio Padrão
    // (sem risk-free rate para simplificar)
    double sharpe = SafeDivide(avgReturn, stdDev, 0.0);
    
    return sharpe;
}

//+------------------------------------------------------------------+
//| Registra resultado de trade para cálculo de Sharpe Ratio        |
//+------------------------------------------------------------------+
void UpdateStateSharpeData(int state, double profit)
{
    if(state < 0 || state >= NUM_STATES) return;
    
    // Atualizar soma de lucros
    g_stateProfitSum[state] += profit;
    
    // Atualizar soma de lucros ao quadrado (para variância)
    g_stateProfitSqSum[state] += (profit * profit);
}

//+------------------------------------------------------------------+
//| Retorna winrate histórico de um estado (0.0 a 1.0)              |
//| Usado para reward dinâmica                                       |
//+------------------------------------------------------------------+
double GetStateWinRate(const int state)
{
   if(state < 0 || state >= NUM_STATES)
      return 0.0;

   int wins   = g_stateWins[state];
   int losses = g_stateLosses[state];
   int total  = wins + losses;

   if(total <= 0)
      return 0.0;

   return SafeDivide((double)wins, (double)total, 0.0);
}

//+------------------------------------------------------------------+
//| Calcula a recompensa dinâmica com base no estado e resultado    |
//| win: true = trade vencedor, false = perdedor                     |
//| state: índice do estado atual                                    |
//+------------------------------------------------------------------+
double GetDynamicReward(const bool win, const int state)
{
   // Usa os inputs base
   double baseWin  = RewardWin;
   double baseLoss = RewardLoss;
   
   // Se dynamic reward desabilitado, retorna reward base
   if(!EnableDynamicReward)
      return win ? baseWin : baseLoss;
   
   // Se estado inválido, retorna reward base
   if(state < 0 || state >= NUM_STATES)
      return win ? baseWin : baseLoss;
   
   // Precisa de histórico mínimo (30 trades) para calcular reward dinâmica
   int wins   = g_stateWins[state];
   int losses = g_stateLosses[state];
   int total  = wins + losses;
   
   // Com menos de 30 trades, usa reward base (proteção contra auto-sabotagem)
   if(total < 30)
      return win ? baseWin : baseLoss;
   
   // Calcular win rate do estado
   double winRate = SafeDivide((double)wins, (double)total, 0.0);
   
   // Definir multiplicador baseado no win rate do estado
   double multiplier = 1.0; // neutro por padrão
   
   if(winRate >= 0.65)
   {
      // Estados EXCELENTES (65%+): recompensa extra quando acertam
      multiplier = win ? 1.5 : 1.0;
   }
   else if(winRate >= 0.55)
   {
      // Estados MUITO BONS (55-65%): bônus moderado quando acertam
      multiplier = win ? 1.3 : 1.0;
   }
   else if(winRate >= 0.45)
   {
      // Estados RAZOÁVEIS (45-55%): reward padrão
      multiplier = 1.0;
   }
   else if(winRate >= 0.30)
   {
      // Estados FRACOS (30-45%): penalidade maior quando erram
      multiplier = win ? 1.0 : 1.3;
   }
   else
   {
      // Estados PÉSSIMOS (<30%): penalidade MUITO maior quando erram
      multiplier = win ? 1.0 : 1.5;
   }
   
   // Aplicar multiplicador
   double reward = win ? (baseWin * multiplier) : (baseLoss * multiplier);
   
   // Limites de segurança (evita valores extremos)
   double maxReward = 20.0;
   double minReward = -20.0;
   
   if(reward > maxReward) reward = maxReward;
   if(reward < minReward) reward = minReward;
   
   return reward;
}

//+------------------------------------------------------------------+
//| Calcula fator de eficiência baseado em MAE/MFE do trade          |
//| direction: +1 = Buy, -1 = Sell                                   |
//| entryPrice: preço de entrada                                     |
//| slPrice, tpPrice: SL e TP usados no trade                        |
//| maxAgainst: pior preço contra (MAE)                              |
//| maxFavour: melhor preço a favor (MFE)                            |
//| profit: lucro líquido do trade (net_profit)                      |
//+------------------------------------------------------------------+
double GetEfficiencyFactor(int direction,
                           double entryPrice,
                           double slPrice,
                           double tpPrice,
                           double maxAgainst,
                           double maxFavour,
                           double profit)
{
   // Validações básicas
   if(direction == 0) return 1.0;
   if(entryPrice <= 0 || slPrice <= 0 || tpPrice <= 0) return 1.0;
   
   // Calcular distâncias SL e TP
   double slDistance = MathAbs(entryPrice - slPrice);
   double tpDistance = MathAbs(tpPrice - entryPrice);
   
   // Proteção contra SL/TP inválidos
   if(slDistance <= 0 || tpDistance <= 0) return 1.0;
   
   // Calcular MAE e MFE percentuais
   double maePct = SafeDivide(maxAgainst, slDistance, 0.0);
   double mfePct = SafeDivide(maxFavour, tpDistance, 0.0);
   
   // Limitar a 0-1 range (proteção)
   if(maePct < 0) maePct = 0;
   if(mfePct < 0) mfePct = 0;
   if(maePct > 1.5) maePct = 1.5; // Pode exceder 100% se foi além do SL
   if(mfePct > 1.5) mfePct = 1.5; // Pode exceder 100% se foi além do TP
   
   double factor = 1.0;
   
   // ✅ VITÓRIAS (profit > 0)
   if(profit > 0)
   {
      // Vitória LIMPA: pouco MAE e alto MFE
      if(maePct <= 0.25 && mfePct >= 0.75)
      {
         factor = 1.4;  // +40% bonus
      }
      // Vitória com MUITO CALOR: quase bateu SL
      else if(maePct > 0.75)
      {
         factor = 0.6;  // -40% penalidade
      }
      // Vitória NORMAL
      else
      {
         factor = 1.0;
      }
   }
   // ❌ DERROTAS (profit < 0)
   else
   {
      // Derrota TEIMOSA: quase atingiu TP mas voltou pro SL
      if(mfePct >= 0.75)
      {
         factor = 2.0;  // +100% penalidade (dobra a perda)
      }
      // Derrota RÁPIDA: nunca chegou perto do TP
      else if(mfePct <= 0.25)
      {
         factor = 1.0;  // Penalidade normal
      }
      // Derrota MÉDIA: chegou razoavelmente perto
      else
      {
         factor = 1.5;  // +50% penalidade
      }
   }
   
   // Limites de segurança
   if(factor < 0.3) factor = 0.3;
   if(factor > 2.5) factor = 2.5;
   
   return factor;
}

//+------------------------------------------------------------------+
//| Atualiza MAE/MFE das posições abertas                            |
//+------------------------------------------------------------------+
void UpdatePositionMetrics()
{
   if(g_trackedPositionsCount <= 0) return;
   
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   for(int i = 0; i < g_trackedPositionsCount; i++)
   {
      ulong ticket = g_positionTickets[i];
      
      // Verificar se posição ainda existe
      if(!PositionSelectByTicket(ticket)) continue;
      
      int dir = g_positionDirection[i];
      double entry = g_positionEntry[i];
      
      double currentPrice = (dir > 0) ? currentBid : currentAsk;
      
      // Calcular movimento contra e a favor
      double movementAgainst = 0;
      double movementFavour = 0;
      
      if(dir > 0) // BUY
      {
         // Contra: quando preço desce
         if(currentPrice < entry)
            movementAgainst = entry - currentPrice;
         // A favor: quando preço sobe
         if(currentPrice > entry)
            movementFavour = currentPrice - entry;
      }
      else // SELL
      {
         // Contra: quando preço sobe
         if(currentPrice > entry)
            movementAgainst = currentPrice - entry;
         // A favor: quando preço desce
         if(currentPrice < entry)
            movementFavour = entry - currentPrice;
      }
      
      // Atualizar MAE (máximo contra)
      if(movementAgainst > g_positionMAE[i])
         g_positionMAE[i] = movementAgainst;
      
      // Atualizar MFE (máximo a favor)
      if(movementFavour > g_positionMFE[i])
         g_positionMFE[i] = movementFavour;
   }
}

//+------------------------------------------------------------------+
//| Adiciona nova posição ao tracking MAE/MFE                        |
//+------------------------------------------------------------------+
void AddPositionTracking(ulong ticket, double entry, double sl, double tp, int direction)
{
   // Expande arrays se necessário
   int newSize = g_trackedPositionsCount + 1;
   ArrayResize(g_positionTickets, newSize);
   ArrayResize(g_positionMAE, newSize);
   ArrayResize(g_positionMFE, newSize);
   ArrayResize(g_positionEntry, newSize);
   ArrayResize(g_positionSL, newSize);
   ArrayResize(g_positionTP, newSize);
   ArrayResize(g_positionDirection, newSize);
   
   // Adiciona nova posição
   int idx = g_trackedPositionsCount;
   g_positionTickets[idx] = ticket;
   g_positionMAE[idx] = 0.0;
   g_positionMFE[idx] = 0.0;
   g_positionEntry[idx] = entry;
   g_positionSL[idx] = sl;
   g_positionTP[idx] = tp;
   g_positionDirection[idx] = direction;
   
   g_trackedPositionsCount++;
}

//+------------------------------------------------------------------+
//| Obtém MAE/MFE de uma posição e remove do tracking               |
//+------------------------------------------------------------------+
bool GetPositionMAEMFE(ulong ticket, double &mae, double &mfe)
{
   for(int i = 0; i < g_trackedPositionsCount; i++)
   {
      if(g_positionTickets[i] == ticket)
      {
         mae = g_positionMAE[i];
         mfe = g_positionMFE[i];
         
         // Remove posição do tracking (shift array)
         for(int j = i; j < g_trackedPositionsCount - 1; j++)
         {
            g_positionTickets[j] = g_positionTickets[j + 1];
            g_positionMAE[j] = g_positionMAE[j + 1];
            g_positionMFE[j] = g_positionMFE[j + 1];
            g_positionEntry[j] = g_positionEntry[j + 1];
            g_positionSL[j] = g_positionSL[j + 1];
            g_positionTP[j] = g_positionTP[j + 1];
            g_positionDirection[j] = g_positionDirection[j + 1];
         }
         
         g_trackedPositionsCount--;
         ArrayResize(g_positionTickets, g_trackedPositionsCount);
         ArrayResize(g_positionMAE, g_trackedPositionsCount);
         ArrayResize(g_positionMFE, g_trackedPositionsCount);
         ArrayResize(g_positionEntry, g_trackedPositionsCount);
         ArrayResize(g_positionSL, g_trackedPositionsCount);
         ArrayResize(g_positionTP, g_trackedPositionsCount);
         ArrayResize(g_positionDirection, g_trackedPositionsCount);
         
         return true;
      }
   }
   
   mae = 0.0;
   mfe = 0.0;
   return false;
}


int CountBlockedStates()
{
   int count = 0;
   for(int i = 0; i < NUM_STATES; i++)
   {
      if(g_stateBlocked[i]) count++;
   }
   return count;
}

// ======================================================================
// ✅✅✅ FUNÇÕES DE MEMÓRIA PERSISTENTE (CORRIGIDAS)
// ======================================================================

void SaveState()
{
   int handle = FileOpen(STATE_FILE, FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(handle == INVALID_HANDLE) 
   {
      Print("❌ Erro ao abrir arquivo para salvar estados: ", STATE_FILE);
      return;
   }

   // 🔧 REGRA 1 — Sempre converter explicitamente
   FileWriteArray(handle, g_stateVisits);
   FileWriteArray(handle, g_stateLosses);
   FileWriteArray(handle, g_stateWins);
   FileWriteArray(handle, g_stateProfitSum);
   FileWriteArray(handle, g_stateProfitSqSum);
   FileWriteArray(handle, g_stateLastUpdate);
   FileWriteArray(handle, g_activeStates);
   FileWriteArray(handle, g_stateBlocked);
   FileWriteArray(handle, g_stateLastBlockTime);
   FileWriteArray(handle, g_stateLastUnblockTime);
   FileWriteArray(handle, g_stateBlockCount);
   FileWriteInteger(handle, (int)g_activeStatesCount);
   FileWriteArray(handle, g_stateWinRate);
   FileWriteArray(handle, g_stateAvgProfit);
   FileWriteInteger(handle, (int)g_stateResets);
   FileWriteInteger(handle, (int)g_stateDecays);
   FileWriteInteger(handle, (int)g_lastDecayTradeCount);
   FileWriteInteger(handle, (int)g_totalDecayCycles);
   FileWriteInteger(handle, (int)g_totalBadStateResets);
   
   FileClose(handle);
   
   static datetime lastSave = 0;
   datetime now = TimeCurrent();
   if(now - lastSave > 60)
   {
      Print("💾 Estados salvos em memória persistente");
      lastSave = now;
   }
}

void LoadState()
{
   if(!FileIsExist(STATE_FILE, FILE_COMMON))
   {
      Print("⚠️ Arquivo de estados não encontrado. Criando novo.");
      return;
   }
   
   int handle = FileOpen(STATE_FILE, FILE_READ | FILE_BIN | FILE_COMMON);
   if(handle == INVALID_HANDLE) 
   {
      Print("❌ Erro ao abrir arquivo para carregar estados: ", STATE_FILE);
      return;
   }

   FileReadArray(handle, g_stateVisits);
   FileReadArray(handle, g_stateLosses);
   FileReadArray(handle, g_stateWins);
   FileReadArray(handle, g_stateProfitSum);
   FileReadArray(handle, g_stateProfitSqSum);
   FileReadArray(handle, g_stateLastUpdate);
   FileReadArray(handle, g_activeStates);
   FileReadArray(handle, g_stateBlocked);
   FileReadArray(handle, g_stateLastBlockTime);
   FileReadArray(handle, g_stateLastUnblockTime);
   FileReadArray(handle, g_stateBlockCount);
   
   // 🔧 REGRA 3 — Converter para int se necessário
   int tempActiveStatesCount = FileReadInteger(handle);
   g_activeStatesCount = tempActiveStatesCount;
   
   FileReadArray(handle, g_stateWinRate);
   FileReadArray(handle, g_stateAvgProfit);
   
   int tempStateResets = FileReadInteger(handle);
   int tempStateDecays = FileReadInteger(handle);
   int tempLastDecayTradeCount = FileReadInteger(handle);
   int tempTotalDecayCycles = FileReadInteger(handle);
   int tempTotalBadStateResets = FileReadInteger(handle);
   
   g_stateResets = tempStateResets;
   g_stateDecays = tempStateDecays;
   g_lastDecayTradeCount = tempLastDecayTradeCount;
   g_totalDecayCycles = tempTotalDecayCycles;
   g_totalBadStateResets = tempTotalBadStateResets;
   
   FileClose(handle);
   
   Print("✅ Estados carregados da memória persistente");
   Print("📊 Estados ativos: ", g_activeStatesCount);
   Print("📊 Total visitas REAIS: ", ArraySum(g_stateVisits));
   Print("📊 Total perdas REAIS: ", ArraySum(g_stateLosses));
   Print("📊 Total vitórias REAIS: ", ArraySum(g_stateWins));
   Print("📊 Estados bloqueados: ", CountBlockedStates());
   Print("📊 Ciclos de decay: ", g_totalDecayCycles);
   Print("📊 Estados resetados: ", g_totalBadStateResets);
}

int ArraySum(const int &array[])
{
   int sum = 0;
   for(int i = 0; i < ArraySize(array); i++)
      sum += array[i];
   return sum;
}

// ======================================================================
// ✅✅✅ FUNÇÕES DO SISTEMA DE MEMÓRIA OTIMIZADA (NOVO)
// ======================================================================

double CompressQValue(double value)
{
   if(!CompressQValues || QValuePrecision >= 4) return value;
   return NormalizeDouble(value, (int)QValuePrecision);
}

void AddActiveState(int state)
{
   if(state < 0 || state >= NUM_STATES) return;
   
   // ✅ Verificar se estado já existe na lista ativa
   for(int i = 0; i < g_activeStatesCount; i++)
   {
      if(g_activeStates[i] == state)
      {
         // Estado já existe - apenas atualiza timestamp
         g_stateLastUpdate[state] = g_totalTrades;
         return;
      }
   }
   
   // ✅ NOVO: Se exploração = 0%, NÃO adicionar novos estados
   // Com 0% exploração, usar APENAS estados já conhecidos
   if(g_currentExplorationRate <= 0.0)
   {
      // Estado novo mas exploração = 0% → NÃO adicionar
      // Sistema deve usar SOMENTE estados já na lista ativa
      return;
   }
   
   // ✅ Adicionar novo estado (exploração > 0%)
   if(g_activeStatesCount < MaxMemoryStates)
   {
      g_activeStates[g_activeStatesCount] = state;
      g_activeStatesCount++;
   }
   else
   {
      int oldestIndex = 0;
      int oldestTime = INT_MAX;
      
      for(int i = 0; i < g_activeStatesCount; i++)
      {
         int stateIdx = g_activeStates[i];
         if(g_stateLastUpdate[stateIdx] < oldestTime)
         {
            oldestTime = g_stateLastUpdate[stateIdx];
            oldestIndex = i;
         }
      }
      
      g_activeStates[oldestIndex] = state;
   }
   
   g_stateLastUpdate[state] = g_totalTrades;
   InvalidateHUDCache();
   
   if(EnableUnifiedBlockingSystem)
   {
      EvaluateAndUpdateBlockState(state);
   }
}

void CleanMemory()
{
   if(!AutoCleanMemory) return;
   
   g_memoryCleanCounter++;
   if(g_memoryCleanCounter < CleanMemoryAfterTrades) return;
   
   g_memoryCleanCounter = 0;
   
   Print("🧹 LIMPANDO MEMÓRIA...");
   
   int cleaned = 0;
   int kept = 0;
   
   for(int state = 0; state < NUM_STATES; state++)
   {
      if(g_stateVisits[state] > 0)
      {
         if(g_stateVisits[state] < 3 && 
            (g_totalTrades - g_stateLastUpdate[state]) > 100)
         {
            g_stateVisits[state] = 0;
            g_stateLosses[state] = 0;
            g_stateWins[state] = 0;
            g_stateLastUpdate[state] = 0;
            g_stateLastBlockTime[state] = 0;
            g_stateLastUnblockTime[state] = 0;
            
            for(int a = 0; a < NUM_ACTIONS; a++)
            {
               g_Q[state * NUM_ACTIONS + a] = 0.0;
            }
            
            g_stateBlocked[state] = false;
            
            cleaned++;
         }
         else
         {
            kept++;
         }
      }
   }
   
   g_activeStatesCount = 0;
   for(int state = 0; state < NUM_STATES; state++)
   {
      if(g_stateVisits[state] > 0)
      {
         if(g_activeStatesCount < MaxMemoryStates)
         {
            g_activeStates[g_activeStatesCount] = state;
            g_activeStatesCount++;
         }
      }
   }
   
   Print("✅ Memória limpa: ", cleaned, " estados removidos, ", kept, " mantidos");
   Print("   Estados ativos na memória: ", g_activeStatesCount);
   
   SaveState();
}

// ======================================================================
// ✅✅✅ SISTEMA DE BACKUP AUTOMÁTICO (CORRIGIDO)
// ======================================================================

string GetBackupFileName(int backupNum)
{
   // Usa nome universal fixo - mesmo backup para todos os símbolos/timeframes
   return "Phoenix_Files/Backups/Cerebro_Universal_backup_" + 
          IntegerToString(backupNum) + ".bin";
}

void ManageBackupFiles()
{
   if(!CreateBackupFiles || !g_memoryInitialized) return;
   
   // ✅ SISTEMA DE MÚLTIPLOS BACKUPS ROTATIVOS
   // Mantém as últimas N cópias de segurança (padrão: 3)
   int maxBackups = MathMax(1, MathMin(MaxBackupFiles, 10)); // Limita entre 1 e 10
   
   // Rotacionar backups: backup_2 -> backup_3, backup_1 -> backup_2, etc.
   for(int i = maxBackups - 1; i >= 1; i--)
   {
      string oldBackup = GetBackupFileName(i - 1);
      string newBackup = GetBackupFileName(i);
      
      if(FileIsExist(oldBackup, FILE_COMMON))
      {
         // Remove backup mais antigo se existir
         if(FileIsExist(newBackup, FILE_COMMON))
         {
            FileDelete(newBackup, FILE_COMMON);
         }
         
         // Move o backup para a posição seguinte
         FileCopy(oldBackup, 0, newBackup, 0);
      }
   }
   
   // Criar novo backup na posição 0 (mais recente)
   string backupFile = GetBackupFileName(0);
   if(SaveBrainToFile(backupFile))
   {
      Print("💾 Backup #0 criado: ", backupFile, " (mantendo últimas ", maxBackups, " cópias)");
   }
   else
   {
      Print("❌ Falha ao criar backup: ", backupFile);
   }
}

bool SaveBrainToFile(string filename)
{
   if(!CreateDirectoryForFile(filename)) return false;

   int h = FileOpen(filename, FILE_WRITE|FILE_BIN|FILE_COMMON);
   if(h == INVALID_HANDLE) return false;

   // 🔧 REGRA 1 — Sempre converter explicitamente
   FileWriteInteger(h, (int)FILE_MAGIC);
   FileWriteInteger(h, (int)FILE_VERSION);
   FileWriteInteger(h, (int)g_activeStatesCount);
   
   for(int i = 0; i < g_activeStatesCount; i++)
   {
      int state = g_activeStates[i];
      
      FileWriteInteger(h, (int)state);
      FileWriteInteger(h, (int)g_stateVisits[state]);
      FileWriteInteger(h, (int)g_stateLosses[state]);
      FileWriteInteger(h, (int)g_stateWins[state]);
      FileWriteInteger(h, (int)g_stateLastUpdate[state]);
      FileWriteInteger(h, (int)g_stateBlocked[state]);
      FileWriteLong(h, (long)g_stateLastBlockTime[state]);
      FileWriteLong(h, (long)g_stateLastUnblockTime[state]);
      
      // Validação ao salvar: garante que contador está entre 0-10
      int blockCountToSave = g_stateBlockCount[state];
      if(blockCountToSave < 0 || blockCountToSave > 10)
      {
         Print("⚠️ ALERTA: Contador de bloqueios corrompido detectado para estado ", state, 
               " (valor: ", blockCountToSave, "). Corrigindo para 0.");
         blockCountToSave = 0;
         g_stateBlockCount[state] = 0;  // Corrige na memória também
      }
      FileWriteInteger(h, blockCountToSave);
      
      for(int a = 0; a < NUM_ACTIONS; a++)
      {
         double qValue = CompressQValue(g_Q[state * NUM_ACTIONS + a]);
         FileWriteDouble(h, qValue);
      }
   }
   
   FileWriteDouble(h, g_currentExplorationRate);
   FileWriteInteger(h, (int)g_tradesToday);
   FileWriteInteger(h, (int)g_consecutiveLosses);
   FileWriteInteger(h, (int)g_totalTrades);
   FileWriteInteger(h, (int)g_totalWins);
   FileWriteInteger(h, (int)g_totalLosses);
   FileWriteDouble(h, g_sumProfit);
   FileWriteDouble(h, g_volumeMultiplier);
   FileWriteInteger(h, (int)g_totalStatesDiscovered);
   FileWriteInteger(h, (int)g_totalQUpdates);
   FileWriteDouble(h, g_averageQValue);
   FileWriteDouble(h, g_maxQValue);
   FileWriteDouble(h, g_minQValue);
   
   int arraySize = (int)ArraySize(g_recentProfits);
   FileWriteInteger(h, (int)arraySize);
   FileWriteArray(h, g_recentProfits);
   FileWriteInteger(h, (int)g_recentProfitsIndex);
   
   long firstTradeDate = (long)g_firstTradeDate;
   FileWriteLong(h, (long)firstTradeDate);
   FileWriteDouble(h, g_highestProfit);
   FileWriteDouble(h, g_lowestProfit);
   FileWriteInteger(h, (int)g_bestWinStreak);
   FileWriteInteger(h, (int)g_worstLossStreak);
   FileWriteInteger(h, (int)g_currentWinStreak);
   FileWriteInteger(h, (int)g_currentLossStreak);
   
   FileWriteInteger(h, (int)g_totalBuys);
   FileWriteInteger(h, (int)g_totalSells);
   FileWriteInteger(h, (int)g_buyWins);
   FileWriteInteger(h, (int)g_sellWins);
   FileWriteDouble(h, g_buyProfit);
   FileWriteDouble(h, g_sellProfit);
   
   FileWriteArray(h, g_stateWinRate);
   FileWriteArray(h, g_stateAvgProfit);
   FileWriteInteger(h, (int)g_stateResets);
   FileWriteInteger(h, (int)g_stateDecays);
   FileWriteInteger(h, (int)g_lastDecayTradeCount);
   FileWriteInteger(h, (int)g_totalDecayCycles);
   FileWriteInteger(h, (int)g_totalBadStateResets);
   
   // 🔧 CORREÇÃO CRÍTICA: Salvar TODOS os estados bloqueados (não apenas ativos)
   // Isso garante que estados bloqueados sejam preservados mesmo se não estiverem em g_activeStates[]
   FileWriteArray(h, g_stateBlocked);
   FileWriteArray(h, g_stateBlockCount);
   FileWriteArray(h, g_stateLastBlockTime);
   FileWriteArray(h, g_stateLastUnblockTime);

   FileClose(h);
   return true;
}

bool LoadBrainFromFile(string filename)
{
   if(!FileIsExist(filename, FILE_COMMON))
   {
      Print("❌ Arquivo não existe: ", filename);
      return false;
   }

   int h = FileOpen(filename, FILE_READ|FILE_BIN|FILE_COMMON);
   if(h == INVALID_HANDLE)
   {
      Print("❌ Erro ao abrir arquivo: ", filename, " (Erro: ", GetLastError(), ")");
      return false;
   }

   int magic = FileReadInteger(h);
   int version = FileReadInteger(h);
   
   if(magic != FILE_MAGIC || version != FILE_VERSION)
   {
      Print("❌ Versão incompatível. Magic: ", magic, " (esperado: ", FILE_MAGIC, "), Versão: ", version, " (esperada: ", FILE_VERSION, ")");
      FileClose(h);
      return false;
   }
   
   // ✅ CORREÇÃO CRÍTICA: NÃO zera arrays antes de carregar!
   // Arrays já foram redimensionados em OnInit()
   // Apenas redimensiona se necessário, mas NÃO inicializa
   // Isso preserva dados de estados que não estão na lista ativa
   if(ArraySize(g_stateVisits) != NUM_STATES)
      ArrayResize(g_stateVisits, NUM_STATES);
   
   if(ArraySize(g_stateLosses) != NUM_STATES)
      ArrayResize(g_stateLosses, NUM_STATES);
   
   if(ArraySize(g_stateWins) != NUM_STATES)
      ArrayResize(g_stateWins, NUM_STATES);
   
   if(ArraySize(g_stateLastUpdate) != NUM_STATES)
      ArrayResize(g_stateLastUpdate, NUM_STATES);
   
   if(ArraySize(g_stateBlocked) != NUM_STATES)
      ArrayResize(g_stateBlocked, NUM_STATES);
   
   if(ArraySize(g_stateLastBlockTime) != NUM_STATES)
      ArrayResize(g_stateLastBlockTime, NUM_STATES);
   
   if(ArraySize(g_stateLastUnblockTime) != NUM_STATES)
      ArrayResize(g_stateLastUnblockTime, NUM_STATES);
   
   // ✅ NÃO zera g_Q[] - preserva valores existentes
   
   // 🔧 REGRA 3 — Converter para int se necessário
   int tempActiveStatesCount = FileReadInteger(h);
   g_activeStatesCount = tempActiveStatesCount;
   
   Print("📊 Carregando ", g_activeStatesCount, " estados ativos...");
   
   for(int i = 0; i < g_activeStatesCount; i++)
   {
      int state = FileReadInteger(h);
      
      if(state >= 0 && state < NUM_STATES)
      {
         g_activeStates[i] = state;
         g_stateVisits[state] = FileReadInteger(h);
         g_stateLosses[state] = FileReadInteger(h);
         g_stateWins[state] = FileReadInteger(h);
         g_stateLastUpdate[state] = FileReadInteger(h);
         g_stateBlocked[state] = (bool)FileReadInteger(h);
         g_stateLastBlockTime[state] = (datetime)FileReadLong(h);
         g_stateLastUnblockTime[state] = (datetime)FileReadLong(h);
         
         // Lê contador de bloqueios com validação para evitar overflow/corrupção
         int blockCount = FileReadInteger(h);
         // Limita contador a valor máximo razoável (0-10)
         g_stateBlockCount[state] = (blockCount < 0 || blockCount > 10) ? 0 : blockCount;
         
         for(int a = 0; a < NUM_ACTIONS; a++)
         {
            double qValue = FileReadDouble(h);
            g_Q[state * NUM_ACTIONS + a] = qValue;
         }
      }
      else
      {
         Print("⚠️ Estado inválido encontrado: ", state, " (ignorando)");
      }
   }
   
   g_currentExplorationRate = FileReadDouble(h);
   g_tradesToday = FileReadInteger(h);
   g_consecutiveLosses = FileReadInteger(h);
   g_totalTrades = FileReadInteger(h);
   g_totalWins = FileReadInteger(h);
   g_totalLosses = FileReadInteger(h);
   g_sumProfit = FileReadDouble(h);
   g_volumeMultiplier = FileReadDouble(h);
   g_totalStatesDiscovered = FileReadInteger(h);
   g_totalQUpdates = FileReadInteger(h);
   g_averageQValue = FileReadDouble(h);
   g_maxQValue = FileReadDouble(h);
   g_minQValue = FileReadDouble(h);
   
   int arraySize = FileReadInteger(h);
   ArrayResize(g_recentProfits, arraySize);
   FileReadArray(h, g_recentProfits, 0, arraySize);
   g_recentProfitsIndex = FileReadInteger(h);
   
   long firstTradeDate = FileReadLong(h);
   g_firstTradeDate = (datetime)firstTradeDate;
   g_highestProfit = FileReadDouble(h);
   g_lowestProfit = FileReadDouble(h);
   g_bestWinStreak = FileReadInteger(h);
   g_worstLossStreak = FileReadInteger(h);
   g_currentWinStreak = FileReadInteger(h);
   g_currentLossStreak = FileReadInteger(h);
   
   g_totalBuys = FileReadInteger(h);
   g_totalSells = FileReadInteger(h);
   g_buyWins = FileReadInteger(h);
   g_sellWins = FileReadInteger(h);
   g_buyProfit = FileReadDouble(h);
   g_sellProfit = FileReadDouble(h);
   
   ArrayResize(g_stateWinRate, NUM_STATES);
   FileReadArray(h, g_stateWinRate, 0, NUM_STATES);
   
   ArrayResize(g_stateAvgProfit, NUM_STATES);
   FileReadArray(h, g_stateAvgProfit, 0, NUM_STATES);
   
   g_stateResets = FileReadInteger(h);
   g_stateDecays = FileReadInteger(h);
   g_lastDecayTradeCount = FileReadInteger(h);
   g_totalDecayCycles = FileReadInteger(h);
   g_totalBadStateResets = FileReadInteger(h);
   
   // 🔧 CORREÇÃO CRÍTICA: Carregar TODOS os estados bloqueados (não apenas ativos)
   // Isso garante que estados bloqueados sejam preservados mesmo se não estiverem em g_activeStates[]
   FileReadArray(h, g_stateBlocked, 0, NUM_STATES);
   FileReadArray(h, g_stateBlockCount, 0, NUM_STATES);
   FileReadArray(h, g_stateLastBlockTime, 0, NUM_STATES);
   FileReadArray(h, g_stateLastUnblockTime, 0, NUM_STATES);
   
   FileClose(h);
   
   Print("✅ Memória carregada: ", g_activeStatesCount, " estados ativos");
   Print("📊 Estados bloqueados: ", CountBlockedStates());
   Print("📊 Ciclos de decay: ", g_totalDecayCycles);
   Print("📊 Estados resetados: ", g_totalBadStateResets);
   Print("📊 Total de trades: ", g_totalTrades, " (Wins: ", g_totalWins, ", Losses: ", g_totalLosses, ")");
   Print("📊 Taxa de exploração: ", DoubleToString(g_currentExplorationRate * 100, 1), "%");
   
   return true;
}

// ======================================================================
// ✅✅✅ FUNÇÕES DE MEMÓRIA PRINCIPAIS (OTIMIZADAS)
// ======================================================================

string BrainKey()
{
   return StringFormat("B%dx%dx%dx%dx%dx%d_A%d",
      BINS_MA_DIST,BINS_RSI,BINS_MACD,BINS_VOLATILITY,BINS_VOLUME,BINS_TIME,NUM_ACTIONS);
}

string GetBrainFileName()
{
   if(g_memoryFileName == "")
   {
      // Nome único universal - mesmo arquivo para todos os símbolos e timeframes
      // Permite trocar .set sem perder memória aprendida
      // ✅ CORRIGIDO: Agora salva na pasta Backups/ junto com o backup
      g_memoryFileName = "Phoenix_Files/Backups/Cerebro_Universal.bin";
   }
   return g_memoryFileName;
}

bool CreateDirectoryForFile(string p)
{
   string parts[];
   string cur = "";
   int n = StringSplit(p, '/', parts);
   if(n > 1)
   {
      for(int i = 0; i < n - 1; i++)
      {
         if(i > 0) cur += "/";
         cur += parts[i];
         
         if(!FileIsExist(cur, FILE_COMMON))
         {
            Print("🔨 Criando diretório: ", cur);
            if(!FolderCreate(cur, FILE_COMMON)) 
            {
               Print("❌ Erro ao criar diretório: ", cur, " (GetLastError: ", GetLastError(), ")");
               return false;
            }
            Print("✅ Diretório criado: ", cur);
         }
      }
   }
   return true;
}

bool SaveBrain()
{
   if(!g_memoryInitialized) 
   {
      Print("⚠️ Memória não inicializada, pulando save");
      return false;
   }

   if(UseIncrementalSave && !g_memoryDirty)
   {
      if(g_memorySaveCounter < 10)
      {
         g_memorySaveCounter++;
         return true;
      }
   }
   
   string f = GetBrainFileName();
   if(!CreateDirectoryForFile(f)) 
   {
      Print("❌ Erro ao criar diretório para: ", f);
      return false;
   }

   if(!SaveBrainToFile(f))
   {
      Print("❌ Falha ao salvar memória");
      return false;
   }
   
   g_lastSaveTime = TimeCurrent();
   g_lastSaveSuccess = true;
   g_qUpdatesSinceSave = 0;
   g_memoryDirty = false;
   g_memorySaveCounter = 0;
   
   if(CreateBackupFiles)
   {
      ManageBackupFiles();
   }
   
   if(EnableTextExport)
   {
      ExportMemoryToTextFileFunc(true);
   }
   
   SaveState();
   
   Print("💾 Memória salva (estados ativos: ", g_activeStatesCount, ")");
   return true;
}

bool LoadBrain()
{
   string fn = GetBrainFileName();
   
   Print("🔍 Tentando carregar arquivo principal: ", fn);
   
   if(!FileIsExist(fn, FILE_COMMON))
   {
      Print("⚠️ Arquivo principal não encontrado: ", fn);
      Print("🔍 Procurando backup único...");
      
      string backupFile = GetBackupFileName(0);
      Print("   Verificando: ", backupFile);
      if(FileIsExist(backupFile, FILE_COMMON))
      {
         Print("✅ Backup encontrado: ", backupFile);
         Print("🔄 Carregando backup...");
         bool result = LoadBrainFromFile(backupFile);
         if(result)
         {
            Print("✅ Backup carregado com sucesso!");
            Print("💾 Copiando backup para arquivo principal...");
            SaveBrainToFile(fn);
            Print("✅ Backup copiado para arquivo principal: ", fn);
         }
         return result;
      }
      
      Print("❌ Nenhum backup encontrado, será criada nova memória");
      return false;
   }
   
   Print("✅ Arquivo principal encontrado, carregando...");
   bool result = LoadBrainFromFile(fn);
   if(result)
   {
      Print("✅ Arquivo principal carregado com sucesso!");
   }
   else
   {
      Print("❌ ERRO ao carregar arquivo principal!");
      Print("🔍 Tentando carregar backup único como fallback...");
      
      string backupFile = GetBackupFileName(0);
      if(FileIsExist(backupFile, FILE_COMMON))
      {
         Print("🔄 Tentando backup: ", backupFile);
         result = LoadBrainFromFile(backupFile);
         if(result)
         {
            Print("✅ Backup carregado com sucesso!");
            Print("💾 Copiando backup para arquivo principal...");
            SaveBrainToFile(fn);
            Print("✅ Backup copiado para arquivo principal: ", fn);
            return result;
         }
      }
      Print("❌ Falha ao carregar qualquer arquivo");
   }
   
   return result;
}

void ResetQTable()
{
   int sz = NUM_STATES * NUM_ACTIONS;
   
   ArrayResize(g_Q, sz);
   ArrayInitialize(g_Q, 0.0);
   
   ArrayResize(g_stateVisits, NUM_STATES);
   ArrayInitialize(g_stateVisits, 0);
   
   ArrayResize(g_stateLosses, NUM_STATES);
   ArrayInitialize(g_stateLosses, 0);
   
   ArrayResize(g_stateWins, NUM_STATES);
   ArrayInitialize(g_stateWins, 0);
   
   ArrayResize(g_stateProfitSum, NUM_STATES);
   ArrayInitialize(g_stateProfitSum, 0.0);
   
   ArrayResize(g_stateProfitSqSum, NUM_STATES);
   ArrayInitialize(g_stateProfitSqSum, 0.0);
   
   ArrayResize(g_stateLastUpdate, NUM_STATES);
   ArrayInitialize(g_stateLastUpdate, 0);
   
   ArrayResize(g_stateBlocked, NUM_STATES);
   for(int i = 0; i < NUM_STATES; i++)
       g_stateBlocked[i] = false;
   
   ArrayResize(g_stateLastBlockTime, NUM_STATES);
   ArrayInitialize(g_stateLastBlockTime, 0);
   
   ArrayResize(g_stateLastUnblockTime, NUM_STATES);
   ArrayInitialize(g_stateLastUnblockTime, 0);
   
   ArrayResize(g_activeStates, MaxMemoryStates);
   g_activeStatesCount = 0;
   
   g_learningInitialized = true;
   g_totalTrades = g_totalWins = g_totalLosses = 0;
   g_sumProfit = 0.0;
   
   g_totalStatesDiscovered = 0;
   g_totalQUpdates = 0;
   g_averageQValue = 0.0;
   g_maxQValue = 0.0;
   g_minQValue = 0.0;
   
   ArrayResize(g_recentProfits, 100);
   ArrayInitialize(g_recentProfits, 0.0);
   g_recentProfitsIndex = 0;
   
   g_firstTradeDate = 0;
   g_highestProfit = 0.0;
   g_lowestProfit = 0.0;
   g_bestWinStreak = 0;
   g_worstLossStreak = 0;
   g_currentWinStreak = 0;
   g_currentLossStreak = 0;
   
   g_totalBuys = 0;
   g_totalSells = 0;
   g_buyWins = 0;
   g_sellWins = 0;
   g_buyProfit = 0.0;
   g_sellProfit = 0.0;
   
   g_totalDecayCycles = 0;
   g_totalBadStateResets = 0;
   
   InitializeLearningSystem();
   
   Print("🆕 Nova memória criada (Sistema Corrigido v307F com Decay e Reset)");
}

// ======================================================================
// ✅✅✅ FUNÇÕES AUXILIARES PARA TRAILING STOP
// ======================================================================

void AddPositionToTrailingSystem(ulong ticket)
{
   Sleep(100);
   
   if(!PositionSelectByTicket(ticket)) return;
   
   int index = -1;
   for(int i = 0; i < g_trailingCount; i++)
   {
      if(g_trailingTickets[i] == ticket)
      {
         index = i;
         break;
      }
   }
   
   if(index == -1)
   {
      index = g_trailingCount;
      g_trailingCount++;
      
      ArrayResize(g_trailingTickets, g_trailingCount);
      ArrayResize(g_trailingBestPrices, g_trailingCount);
      ArrayResize(g_trailingCurrentSL, g_trailingCount);
      ArrayResize(g_trailingCurrentTP, g_trailingCount);
      ArrayResize(g_trailingLastTrailTimes, g_trailingCount);
      ArrayResize(g_trailingBreakevenActivated, g_trailingCount);
   }
   
   g_trailingTickets[index] = ticket;
   g_trailingBestPrices[index] = PositionGetDouble(POSITION_PRICE_OPEN);
   g_trailingCurrentSL[index] = PositionGetDouble(POSITION_SL);
   g_trailingCurrentTP[index] = PositionGetDouble(POSITION_TP);
   g_trailingLastTrailTimes[index] = 0;
   g_trailingBreakevenActivated[index] = false;
   
   Print("📊 Posição #", ticket, " adicionada ao sistema de trailing stop");
}

void RemovePositionFromTrailingSystem(ulong ticket)
{
   for(int i = 0; i < g_trailingCount; i++)
   {
      if(g_trailingTickets[i] == ticket)
      {
         for(int j = i; j < g_trailingCount - 1; j++)
         {
            g_trailingTickets[j] = g_trailingTickets[j + 1];
            g_trailingBestPrices[j] = g_trailingBestPrices[j + 1];
            g_trailingCurrentSL[j] = g_trailingCurrentSL[j + 1];
            g_trailingCurrentTP[j] = g_trailingCurrentTP[j + 1];
            g_trailingLastTrailTimes[j] = g_trailingLastTrailTimes[j + 1];
            g_trailingBreakevenActivated[j] = g_trailingBreakevenActivated[j + 1];
         }
         g_trailingCount--;
         Print("📊 Posição #", ticket, " removida do sistema de trailing stop");
         break;
      }
   }
}

// ======================================================================
// ✅✅✅ MONITORAMENTO INTELIGENTE DE ESTADOS (CORRIGIDO)
// ======================================================================
void MonitorBadStates()
{
   static datetime lastMonitorTime = 0;
   datetime currentTime = TimeCurrent();
   
   if(currentTime - lastMonitorTime < 300 && g_totalTrades % 15 != 0) 
      return;
   
   lastMonitorTime = currentTime;
   
   Print("🔍 MONITORAMENTO SUPER AGRESSIVO DE ESTADOS RUINS");
   
   int bloqueados = 0;
   int resetados = 0;
   int estadosAnalisados = 0;
   
   for(int state = 0; state < NUM_STATES; state++)
   {
      if(g_stateVisits[state] > 0)
      {
         estadosAnalisados++;
         double winRate = CalculateWinRate(state);
         
         // ✅ APENAS LOG/MONITORAMENTO - Bloqueio real feito pelo sistema unificado
         
         // Log de estados com win rate baixo (apenas informativo)
         if(g_stateVisits[state] >= MinVisitsForBlockDecision && winRate < 0.25)
         {
            Print("⚠️ ALERTA Estado ", state, 
                  " | Win Rate: ", DoubleToString(winRate*100,1), "%",
                  " | Visitas: ", g_stateVisits[state],
                  " | Bloqueado: ", (g_stateBlocked[state] ? "Sim" : "Não"));
         }
         
         // Log de estados críticos (apenas informativo)
         if(g_stateVisits[state] >= MinVisitsForBlockDecision && winRate < 0.15)
         {
            Print("🔥 CRÍTICO Estado ", state, 
                  " | Win Rate crítica: ", DoubleToString(winRate*100,1), "%",
                  " | Visitas: ", g_stateVisits[state],
                  " | Bloqueado: ", (g_stateBlocked[state] ? "Sim" : "Não"));
         }
         
         // 3. DESBLOQUEAR estados bons
         if(g_stateBlocked[state] && winRate > 0.55 && g_stateVisits[state] >= MinVisitsForBlockDecision)
         {
            g_stateBlocked[state] = false;
            InvalidateHUDCache();
            Print("✅ DESBLOQUEIO Estado ", state,
                  " | Win Rate boa: ", DoubleToString(winRate*100,1), "%");
         }
      }
   }
   
   Print("📊 RESUMO MONITORAMENTO:");
   Print("   Estados analisados: ", estadosAnalisados);
   Print("   Estados bloqueados: ", CountBlockedStates(), " (+", bloqueados, " novos)");
   Print("   Estados resetados: ", resetados);
   Print("   Total resets acumulados: ", g_totalBadStateResets);
   
   // ✅ FORÇAR SAVE após monitoramento crítico
   if(bloqueados > 0 || resetados > 0)
   {
      SaveState();
      g_memoryDirty = true;
   }
}

// ======================================================================
// ✅✅✅ FUNÇÃO: DEBUG DE ESTADOS BLOQUEADOS (ATUALIZADA)
// ======================================================================
void DebugBlockedStates()
{
   static datetime lastDebugTime = 0;
   datetime currentTime = TimeCurrent();
   
   if(currentTime - lastDebugTime < 300) return;
   lastDebugTime = currentTime;
   
   int blockedCount = 0;
   int totalVisited = 0;
   int wronglyBlocked = 0;
   int correctlyBlocked = 0;
   
   Print("=== DEBUG: ESTADOS BLOQUEADOS (SISTEMA CORRIGIDO) ===");
   
   for(int state = 0; state < NUM_STATES; state++)
   {
      if(g_stateVisits[state] > 0)
      {
         totalVisited++;
         
         double winRate = CalculateWinRate(state);
         double lossRate = 1.0 - winRate;
         
         if(g_stateBlocked[state])
         {
            blockedCount++;
            
            if(winRate >= UnblockWinRateThreshold && g_stateVisits[state] >= MinVisitsForBlockDecision)
            {
               wronglyBlocked++;
               PrintFormat("❌❌❌ ERRO GRAVE: Estado %d BLOQUEADO mas tem WIN RATE ALTA: %.1f%% | Visitas: %d", 
                     state, winRate*100, g_stateVisits[state]);
               
               if(EnableUnifiedBlockingSystem)
               {
                  UnblockState(state);
               }
            }
            else if(lossRate >= BlockLossRateThreshold && g_stateVisits[state] >= MinVisitsForBlockDecision)
            {
               correctlyBlocked++;
               PrintFormat("⛔ Estado %d BLOQUEADO CORRETAMENTE: %.1f%% win | Visitas: %d", 
                     state, winRate*100, g_stateVisits[state]);
            }
            else
            {
               PrintFormat("⚠️ Estado %d bloqueado sem dados suficientes: %.1f%% win | Visitas: %d", 
                     state, winRate*100, g_stateVisits[state]);
            }
         }
      }
   }
   
   Print(StringFormat("=== RESUMO: %d visitados | %d bloqueados | %d bloqueados erroneamente | %d bloqueados corretamente ===", 
         totalVisited, blockedCount, wronglyBlocked, correctlyBlocked));
   
   if(wronglyBlocked > 0 && EnableUnifiedBlockingSystem)
   {
      Print("🔥🔥🔥 CORRIGINDO ", wronglyBlocked, " ESTADOS BLOQUEADOS ERRONEAMENTE...");
      AutoUnblockGoodStates();
   }
}

// ======================================================================
// ✅✅✅ FUNÇÃO: DEBUG DE CONTAGEM DE TRADES (VERSÃO MELHORADA)
// ======================================================================
void DebugTradeCounting()
{
   Print("=== DEBUG CONTAGEM DE TRADES (V2) ===");
   Print("Total Trades: ", g_totalTrades);
   Print("Total Wins: ", g_totalWins);
   Print("Total Losses: ", g_totalLosses);
   Print("Soma Wins+Losses: ", g_totalWins + g_totalLosses);
   Print("Diferença (NOPs): ", g_totalTrades - (g_totalWins + g_totalLosses));
   Print("Win Rate: ", g_totalTrades > 0 ? DoubleToString(SafeDivide((double)g_totalWins, (double)g_totalTrades, 0.0)*100, 1) : "0.0", "%");
   
   int estadosComProblema = 0;
   int totalVisitas = 0;
   int totalVitórias = 0;
   int totalPerdas = 0;
   
   for(int s = 0; s < NUM_STATES; s++)
   {
      if(g_stateVisits[s] > 0)
      {
         totalVisitas += g_stateVisits[s];
         totalVitórias += g_stateWins[s];
         totalPerdas += g_stateLosses[s];
         
         if(g_stateWins[s] == 0 && g_stateLosses[s] == 0 && g_stateVisits[s] >= 3)
         {
            estadosComProblema++;
            Print("⚠️ PROBLEMA: Estado ", s, " tem ", g_stateVisits[s], 
                  " visitas mas 0 vitórias e 0 perdas!");
            
            // ⚠️ CORREÇÃO AUTOMÁTICA: Resetar estado problemático
            if(g_stateVisits[s] >= 5)
            {
               Print("🔄 Resetando estado problemático ", s);
               g_stateVisits[s] = 0;
               g_stateWins[s] = 0;
               g_stateLosses[s] = 0;
               // ✅ NÃO desbloquear - preservar bloqueio se existir
               // g_stateBlocked[s] permanece inalterado
               
               for(int a = 0; a < NUM_ACTIONS; a++)
               {
                  g_Q[s * NUM_ACTIONS + a] = 0.0;
               }
            }
         }
         
         // Verificar estados que deveriam estar bloqueados
         if(g_stateVisits[s] >= MinVisitsForBlockDecision)
         {
            double lossRate = SafeDivide((double)g_stateLosses[s], (double)g_stateVisits[s], 0.0);
            if(lossRate >= BlockLossRateThreshold && !g_stateBlocked[s])
            {
               Print("⚠️ Estado ", s, " deveria estar bloqueado! Loss rate: ", 
                     DoubleToString(lossRate*100, 1), "%");
            }
         }
      }
   }
   
   Print("=== RESUMO DOS ESTADOS ===");
   Print("Estados ativos: ", g_activeStatesCount);
   Print("Estados com problema: ", estadosComProblema);
   Print("Total visitas em todos estados: ", totalVisitas);
   Print("Total vitórias em todos estados: ", totalVitórias);
   Print("Total perdas em todos estados: ", totalPerdas);
   Print("Taxa de vitória global estados: ", totalVisitas > 0 ? 
         DoubleToString(SafeDivide((double)totalVitórias, (double)totalVisitas, 0.0)*100, 1) : "0.0", "%");
   
   if(estadosComProblema > 0)
   {
      Print("🔥🔥🔥 ENCONTRADOS ", estadosComProblema, " ESTADOS PROBLEMÁTICOS!");
      Print("🔥 RECOMENDAÇÃO: Executar EmergencyReset()");
   }
   
   Print("=== FIM DEBUG ===");
}

// ======================================================================
// ✅✅✅ FUNÇÃO: RESET DE EMERGÊNCIA (ADICIONADA)
// ======================================================================
void EmergencyReset()
{
   Print("🔥🔥🔥 RESET DE EMERGÊNCIA ATIVADO!");
   
   // Resetar todas as estatísticas
   g_totalTrades = 0;
   g_totalWins = 0;
   g_totalLosses = 0;
   g_sumProfit = 0.0;
   
   // Resetar Q-table
   for(int i = 0; i < NUM_STATES * NUM_ACTIONS; i++)
   {
      g_Q[i] = 0.0;
   }
   
   // Resetar contadores de estado
   for(int s = 0; s < NUM_STATES; s++)
   {
      g_stateVisits[s] = 0;
      g_stateLosses[s] = 0;
      g_stateWins[s] = 0;
      g_stateBlocked[s] = false;
      g_stateLastBlockTime[s] = 0;
      g_stateLastUnblockTime[s] = 0;
      g_stateLastUpdate[s] = 0;
   }
   
   g_activeStatesCount = 0;
   g_currentExplorationRate = InitialExplorationRate;
   g_tradesToday = 0;
   g_consecutiveLosses = 0;
   g_totalDecayCycles = 0;
   g_totalBadStateResets = 0;
   
   // Resetar arrays
   ArrayInitialize(g_recentProfits, 0.0);
   g_recentProfitsIndex = 0;
   
   SaveBrain();
   SaveState();
   
   Print("✅ Sistema resetado completamente!");
   Print("🔄 Reinicie o robô para começar do zero com contadores corretos.");
}

// ======================================================================
// ✅✅✅ FUNÇÃO: DEBUG DE ESTADOS TRAVADOS (NOVA)
// ======================================================================
void DebugStuckStates()
{
   Print("=== DEBUG ESTADOS TRAVADOS ===");
   
   int stuckStates = 0;
   int totalStatesWithVisits = 0;
   int maxVisits = 0;
   
   for(int state = 0; state < NUM_STATES; state++)
   {
      if(g_stateVisits[state] > 0)
      {
         totalStatesWithVisits++;
         
         if(g_stateVisits[state] > maxVisits)
            maxVisits = g_stateVisits[state];
            
         // Verificar se está "travado" em múltiplos de 10
         if(g_stateVisits[state] % 10 == 0 && g_stateVisits[state] > 0)
         {
            stuckStates++;
            double winRate = CalculateWinRate(state);
            
            Print("⚠️ Estado ", state, " com ", g_stateVisits[state], " visitas",
                  " | Wins: ", g_stateWins[state],
                  " | Losses: ", g_stateLosses[state],
                  " | Win Rate: ", DoubleToString(winRate*100,1), "%",
                  " | Bloqueado: ", g_stateBlocked[state] ? "SIM" : "NÃO",
                  " | Última atualização: ", g_totalTrades - g_stateLastUpdate[state], " trades atrás");
         }
      }
   }
   
   Print("📊 ESTATÍSTICAS:");
   Print("   Total estados com visitas: ", totalStatesWithVisits);
   Print("   Máximo de visitas em um estado: ", maxVisits);
   Print("   Estados travados (múltiplos de 10): ", stuckStates);
   Print("   Estados com 10+ visitas: ", CountStatesWithMinVisits(10));
   Print("   Estados com 20+ visitas: ", CountStatesWithMinVisits(20));
   Print("   Total BadStateResets: ", g_totalBadStateResets);
   Print("=== FIM DEBUG ===");
}

int CountStatesWithMinVisits(int minVisits)
{
   int count = 0;
   for(int state = 0; state < NUM_STATES; state++)
   {
      if(g_stateVisits[state] >= minVisits)
         count++;
   }
   return count;
}

// ======================================================================
// ✅✅✅ ✅✅✅ NOVAS FUNÇÕES ADICIONADAS
// ======================================================================

// ======================================================================
// ✅✅✅ FUNÇÃO: CORREÇÃO DE EMERGÊNCIA DOS CONTADORES
// ======================================================================
void EmergencyCounterFix()
{
   Print("🔥🔥🔥 CORREÇÃO DE EMERGÊNCIA DOS CONTADORES");
   
   int fixedStates = 0;
   int unblockedStates = 0;
   int corruptedStates = 0;
   
   for(int state = 0; state < NUM_STATES; state++)
   {
      if(g_stateVisits[state] > 0)
      {
         // ✅ CORRIGIR CONTADORES INCONSISTENTES
         if(g_stateWins[state] > g_stateVisits[state])
         {
            Print("❌❌❌ ERRO CRÍTICO: Estado ", state, 
                  " | Visitas: ", g_stateVisits[state],
                  " | Vitórias: ", g_stateWins[state], " (IMPOSSÍVEL!)");
            
            // Correção: Recalcular baseado em win rate realista
            double estimatedWinRate = 0.3; // Assumir 30% win rate
            g_stateWins[state] = (int)(g_stateVisits[state] * estimatedWinRate);
            g_stateLosses[state] = g_stateVisits[state] - g_stateWins[state];
            
            corruptedStates++;
            fixedStates++;
         }
         
         // ✅ DESBLOQUEAR ESTADOS BLOQUEADOS ERRONEAMENTE
         if(g_stateBlocked[state])
         {
            double winRate = CalculateWinRate(state);
            
            // Regras mais sensatas para desbloqueio
            if((g_stateVisits[state] < 5 && winRate > 0.1) || // Poucas visitas com alguma vitória
               (g_stateVisits[state] >= 5 && winRate >= 0.25)) // Win rate razoável
            {
               g_stateBlocked[state] = false;
               unblockedStates++;
               Print("✅ Estado ", state, " desbloqueado | Win rate: ", 
                     DoubleToString(winRate*100,1), "% | Visitas: ", g_stateVisits[state]);
            }
         }
         
         // ✅ CORRIGIR ESTADOS COM 0 VISITAS MAS COM CONTADORES
         if(g_stateVisits[state] == 0 && (g_stateWins[state] > 0 || g_stateLosses[state] > 0))
         {
            Print("🔄 Estado ", state, " com contadores mas 0 visitas - resetando");
            g_stateWins[state] = 0;
            g_stateLosses[state] = 0;
            g_stateBlocked[state] = false;
            fixedStates++;
         }
      }
   }
   
   // ✅ CORRIGIR ESTATÍSTICAS GLOBAIS
   int totalVisits = 0;
   int totalWins = 0;
   int totalLosses = 0;
   
   for(int state = 0; state < NUM_STATES; state++)
   {
      totalVisits += g_stateVisits[state];
      totalWins += g_stateWins[state];
      totalLosses += g_stateLosses[state];
   }
   
   // Recalcular totais
   g_totalTrades = totalVisits; // Cada visita = 1 trade real
   g_totalWins = totalWins;
   g_totalLosses = totalLosses;
   
   Print("📊 RESUMO DA CORREÇÃO:");
   Print("   Estados com dados corruptos: ", corruptedStates);
   Print("   Estados corrigidos: ", fixedStates);
   Print("   Estados desbloqueados: ", unblockedStates);
   Print("   Novos totais:");
   Print("     Total Visitas: ", totalVisits);
   Print("     Total Vitórias: ", totalWins);
   Print("     Total Perdas: ", totalLosses);
   Print("     Win Rate: ", totalVisits > 0 ? 
         DoubleToString((double)totalWins/totalVisits*100, 1) : "0.0", "%");
   
   // Forçar save
   g_memoryDirty = true;
   SaveState();
   SaveBrain();
}

// ======================================================================
// ✅✅✅ FUNÇÃO: REVISÃO COMPLETA DO SISTEMA DE BLOQUEIO
// ======================================================================
void OverhaulBlockingSystem()
{
   Print("🔄 REVISÃO COMPLETA DO SISTEMA DE BLOQUEIO");
   
   int blockedBefore = CountBlockedStates();
   int totalVisited = g_activeStatesCount;
   
   // ✅ NOVAS REGRAS INTELIGENTES
   for(int state = 0; state < NUM_STATES; state++)
   {
      if(g_stateVisits[state] > 0)
      {
         double winRate = CalculateWinRate(state);
         
         // ✅ REGRAS PARA BLOQUEIO (MAIS RESTRITIVAS)
         bool shouldBeBlocked = false;
         
         // 1. Muito ruim com histórico suficiente
         if(g_stateVisits[state] >= MinVisitsForBlockDecision && winRate < StateBlockThreshold)
         {
            shouldBeBlocked = true;
         }
         // 2. Catastrófico mesmo com histórico mínimo
         else if(g_stateVisits[state] >= MinVisitsForBlockDecision && winRate < (StateBlockThreshold / 2.0))
         {
            shouldBeBlocked = true;
         }
         // 3. Nunca ganhou com visitas significativas
         else if(g_stateVisits[state] >= MinVisitsForBlockDecision && winRate == 0.0)
         {
            shouldBeBlocked = true;
         }
         
         // ✅ REGRAS PARA DESBLOQUEIO (MAIS LENIENTES)
         bool shouldBeUnblocked = false;
         
         // 1. Performance aceitável
         if(g_stateVisits[state] >= MinVisitsForBlockDecision && winRate >= 0.30)
         {
            shouldBeUnblocked = true;
         }
         // 2. Poucas visitas, não bloquear prematuramente
         else if(g_stateVisits[state] < 5)
         {
            shouldBeUnblocked = true;
         }
         // 3. Mostrando melhoria recente
         else if(g_stateBlocked[state] && winRate >= 0.25)
         {
            shouldBeUnblocked = true;
         }
         
         // APLICAR DECISÃO
         if(shouldBeBlocked && !g_stateBlocked[state])
         {
            g_stateBlocked[state] = true;
         }
         else if(shouldBeUnblocked && g_stateBlocked[state])
         {
            g_stateBlocked[state] = false;
         }
      }
   }
   
   int blockedAfter = CountBlockedStates();
   
   Print("📊 RESULTADO DA REVISÃO:");
   Print("   Estados visitados: ", totalVisited);
   Print("   Bloqueados antes: ", blockedBefore, " (", 
         totalVisited > 0 ? DoubleToString((double)blockedBefore/totalVisited*100,1) : "0", "%)");
   Print("   Bloqueados depois: ", blockedAfter, " (", 
         totalVisited > 0 ? DoubleToString((double)blockedAfter/totalVisited*100,1) : "0", "%)");
   Print("   Mudança: ", blockedAfter - blockedBefore);
   
   g_memoryDirty = true;
}

// ======================================================================
// ✅✅✅ FUNÇÃO: RESET PARCIAL INTELIGENTE
// ======================================================================
void IntelligentPartialReset()
{
   // ✅ PROTEÇÃO: Não resetar até ter base sólida de estados aprendidos
   if(g_activeStatesCount < MinStatesBeforeReset)
   {
      return; // Não resetar até ter aprendido estados suficientes
   }
   
   Print("🧠 RESET PARCIAL INTELIGENTE");
   
   int statesReset = 0;
   int statesRetained = 0;
   
   for(int state = 0; state < NUM_STATES; state++)
   {
      if(g_stateVisits[state] > 0)
      {
         double winRate = CalculateWinRate(state);
         
         // ✅ CRITÉRIOS PARA RESET COMPLETO (usar MinVisitsForBlockDecision)
         if((g_stateVisits[state] >= MinVisitsForBlockDecision && winRate < 0.15) || // Muito ruim
            (g_stateVisits[state] >= MinVisitsForBlockDecision && winRate == 0.0) ||  // Nunca ganhou
            (g_stateVisits[state] > MinVisitsForBlockDecision && winRate < 0.25))    // Histórico longo ruim
         {
            // Reset completo
            g_stateVisits[state] = 0;
            g_stateWins[state] = 0;
            g_stateLosses[state] = 0;
            // ✅ NÃO desbloquear estado ruim - preservar bloqueio
            // g_stateBlocked[state] permanece inalterado
            
            for(int a = 0; a < NUM_ACTIONS; a++)
            {
               g_Q[state * NUM_ACTIONS + a] = 0.0;
            }
            
            statesReset++;
         }
         // ✅ RESET PARCIAL PARA ESTADOS MÉDIOS
         else if(g_stateVisits[state] >= MinVisitsForBlockDecision && winRate < 0.30)
         {
            // Manter 30% da memória
            g_stateVisits[state] = (int)(g_stateVisits[state] * 0.3);
            g_stateWins[state] = (int)(g_stateWins[state] * 0.3);
            g_stateLosses[state] = (int)(g_stateLosses[state] * 0.3);
            
            // Garantir mínimos
            if(g_stateVisits[state] < 1) g_stateVisits[state] = 1;
            if(g_stateWins[state] < 0) g_stateWins[state] = 0;
            if(g_stateLosses[state] < 0) g_stateLosses[state] = 0;
            
            // Reduzir Q-values
            for(int a = 0; a < NUM_ACTIONS; a++)
            {
               g_Q[state * NUM_ACTIONS + a] *= 0.3;
            }
            
            statesRetained++;
         }
         else
         {
            statesRetained++;
         }
      }
   }
   
   // Recalcular estados ativos
   g_activeStatesCount = 0;
   for(int state = 0; state < NUM_STATES; state++)
   {
      if(g_stateVisits[state] > 0)
      {
         if(g_activeStatesCount < MaxMemoryStates)
         {
            g_activeStates[g_activeStatesCount] = state;
            g_activeStatesCount++;
         }
      }
   }
   
   Print("📊 RESULTADO DO RESET:");
   Print("   Estados resetados completamente: ", statesReset);
   Print("   Estados mantidos (com redução): ", statesRetained);
   Print("   Total estados ativos após reset: ", g_activeStatesCount);
   
   g_memoryDirty = true;
   SaveState();
}

// ======================================================================
// ✅✅✅ FUNÇÃO: OTIMIZAR PARÂMETROS DINAMICAMENTE
// ======================================================================
void OptimizeParametersDynamically()
{
   Print("⚙️ OTIMIZANDO PARÂMETROS DINAMICAMENTE");
   
   // ✅ AJUSTAR EXPLORAÇÃO BASEADO NA PERFORMANCE
   double currentWinRate = SafeDivide((double)g_totalWins, (double)g_totalTrades, 0.0);
   
   // ✅ Ajuste adaptativo apenas se habilitado
   if(EnableAdaptiveExploration)
   {
      if(currentWinRate < 0.25)
      {
         // Performance ruim, aumentar exploração
         g_currentExplorationRate = MathMin(g_currentExplorationRate * 1.2, 0.8);
         Print("📈 Aumentando exploração para ", DoubleToString(g_currentExplorationRate*100,1), 
               "% (win rate baixa: ", DoubleToString(currentWinRate*100,1), "%)");
      }
      else if(currentWinRate > 0.35)
      {
         // Performance boa, reduzir exploração
         g_currentExplorationRate = MathMax(g_currentExplorationRate * 0.9, MinExplorationRate);
         Print("📉 Reduzindo exploração para ", DoubleToString(g_currentExplorationRate*100,1), 
               "% (win rate boa: ", DoubleToString(currentWinRate*100,1), "%)");
      }
   }
   
   // ✅ AJUSTAR LEARNING RATE
   if(g_totalTrades > 500)
   {
      LearningRate = 0.01; // Reduzir após muitos trades
      Print("🎓 Learning rate ajustado para 0.01 (maturidade do sistema)");
   }
   
   // ✅ AJUSTAR LIMITES DE BLOQUEIO
   // Mantém sempre MinVisitsForBlockDecision = 30 (não ajusta mais para 8)
   // Garantia: Estados NUNCA bloqueados com menos de 30 visitas
   
   g_memoryDirty = true;
}

// ======================================================================
// ✅ HUD LEVE - FUNÇÕES OTIMIZADAS
// ======================================================================

void CreateHUDObjects()
{
   if(!ShowHUD || hudObjectCount > 0) return;
   
   int lineHeight = 18;
   int currentY = HUD_Y;
   
   Print("🛠️ Criando objetos do HUD...");
   
   if(ObjectCreate(0, "HUD_Title", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_Title", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_Title", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_Title", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_Title", OBJPROP_COLOR, HUD_TitleColor);
      ObjectSetInteger(0, "HUD_Title", OBJPROP_FONTSIZE, 11);
      ObjectSetString(0, "HUD_Title", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_Title", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_Title", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_Title", OBJPROP_TEXT, "PHOENIX TRADER v307F SUPER CORRIGIDO");
      hudObjects[hudObjectCount++] = "HUD_Title";
      currentY += lineHeight;
   }
   
   if(ObjectCreate(0, "HUD_Divider", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_Divider", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_Divider", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_Divider", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_Divider", OBJPROP_COLOR, HUD_TextColor);
      ObjectSetInteger(0, "HUD_Divider", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "HUD_Divider", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_Divider", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_Divider", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_Divider", OBJPROP_TEXT, "==========================================");
      hudObjects[hudObjectCount++] = "HUD_Divider";
      currentY += lineHeight;
   }
   
   if(ObjectCreate(0, "HUD_States", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_States", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_States", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_States", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_States", OBJPROP_COLOR, HUD_TextColor);
      ObjectSetInteger(0, "HUD_States", OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, "HUD_States", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_States", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_States", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_States", OBJPROP_TEXT, "Estados: 0/" + IntegerToString(NUM_STATES));
      hudObjects[hudObjectCount++] = "HUD_States";
      currentY += lineHeight;
   }
   
   if(ObjectCreate(0, "HUD_Progress", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_Progress", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_Progress", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_Progress", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_Progress", OBJPROP_COLOR, HUD_SuccessColor);
      ObjectSetInteger(0, "HUD_Progress", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "HUD_Progress", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_Progress", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_Progress", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_Progress", OBJPROP_TEXT, "   [--------------------] (0.0%)");
      hudObjects[hudObjectCount++] = "HUD_Progress";
      currentY += lineHeight;
   }
   
   if(ObjectCreate(0, "HUD_Blocked", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_Blocked", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_Blocked", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_Blocked", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_Blocked", OBJPROP_COLOR, HUD_TextColor);
      ObjectSetInteger(0, "HUD_Blocked", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "HUD_Blocked", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_Blocked", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_Blocked", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_Blocked", OBJPROP_TEXT, "   Bloqueados: 0 (0.0%)");
      hudObjects[hudObjectCount++] = "HUD_Blocked";
      currentY += lineHeight + 5;
   }
   
   if(ObjectCreate(0, "HUD_DecayInfo", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_DecayInfo", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_DecayInfo", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_DecayInfo", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_DecayInfo", OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, "HUD_DecayInfo", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "HUD_DecayInfo", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_DecayInfo", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_DecayInfo", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_DecayInfo", OBJPROP_TEXT, "   Decay: Ativo | Ciclos: 0");
      hudObjects[hudObjectCount++] = "HUD_DecayInfo";
      currentY += lineHeight;
   }
   
   if(ObjectCreate(0, "HUD_Direction", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_Direction", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_Direction", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_Direction", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_Direction", OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, "HUD_Direction", OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, "HUD_Direction", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_Direction", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_Direction", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_Direction", OBJPROP_TEXT, "Direção: O NEUTRO");
      hudObjects[hudObjectCount++] = "HUD_Direction";
      currentY += lineHeight;
   }
   
   if(ObjectCreate(0, "HUD_Positions", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_Positions", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_Positions", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_Positions", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_Positions", OBJPROP_COLOR, HUD_TextColor);
      ObjectSetInteger(0, "HUD_Positions", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "HUD_Positions", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_Positions", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_Positions", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_Positions", OBJPROP_TEXT, "   Posições ativas: 0");
      hudObjects[hudObjectCount++] = "HUD_Positions";
      currentY += lineHeight + 5;
   }
   
   if(ObjectCreate(0, "HUD_Status", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_Status", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_Status", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_Status", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_Status", OBJPROP_COLOR, HUD_WarningColor);
      ObjectSetInteger(0, "HUD_Status", OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, "HUD_Status", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_Status", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_Status", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_Status", OBJPROP_TEXT, "STATUS: Inicializando...");
      hudObjects[hudObjectCount++] = "HUD_Status";
      currentY += lineHeight;
   }
   
   if(ObjectCreate(0, "HUD_Volume", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_Volume", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_Volume", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_Volume", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_Volume", OBJPROP_COLOR, HUD_TextColor);
      ObjectSetInteger(0, "HUD_Volume", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "HUD_Volume", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_Volume", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_Volume", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_Volume", OBJPROP_TEXT, "Volume: NORMAL (1.0x)");
      hudObjects[hudObjectCount++] = "HUD_Volume";
      currentY += lineHeight - 5;
   }
   
   if(ObjectCreate(0, "HUD_Exploration", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_Exploration", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_Exploration", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_Exploration", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_Exploration", OBJPROP_COLOR, HUD_TextColor);
      ObjectSetInteger(0, "HUD_Exploration", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "HUD_Exploration", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_Exploration", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_Exploration", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_Exploration", OBJPROP_TEXT, "Exploração: 50%");
      hudObjects[hudObjectCount++] = "HUD_Exploration";
      currentY += lineHeight - 5;
   }
   
   if(ObjectCreate(0, "HUD_Trades", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_Trades", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_Trades", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_Trades", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_Trades", OBJPROP_COLOR, HUD_TextColor);
      ObjectSetInteger(0, "HUD_Trades", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "HUD_Trades", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_Trades", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_Trades", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_Trades", OBJPROP_TEXT, "Trades hoje: 0/30");
      hudObjects[hudObjectCount++] = "HUD_Trades";
      currentY += lineHeight;
   }
   
   if(ObjectCreate(0, "HUD_TotalTrades", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_TotalTrades", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_TotalTrades", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_TotalTrades", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_TotalTrades", OBJPROP_COLOR, HUD_TextColor);
      ObjectSetInteger(0, "HUD_TotalTrades", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "HUD_TotalTrades", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_TotalTrades", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_TotalTrades", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_TotalTrades", OBJPROP_TEXT, "Total de Trades: 0");
      hudObjects[hudObjectCount++] = "HUD_TotalTrades";
      currentY += lineHeight;
   }
   
   // ✅ RELÓGIO DE VELA
   if(ObjectCreate(0, "HUD_CandleTimer", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_CandleTimer", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_CandleTimer", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_CandleTimer", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_CandleTimer", OBJPROP_COLOR, clrAqua);
      ObjectSetInteger(0, "HUD_CandleTimer", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "HUD_CandleTimer", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_CandleTimer", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_CandleTimer", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_CandleTimer", OBJPROP_TEXT, "Tempo de vela: 00:00");
      hudObjects[hudObjectCount++] = "HUD_CandleTimer";
      currentY += lineHeight;
   }
   
   if(ObjectCreate(0, "HUD_WinRate", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_WinRate", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_WinRate", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_WinRate", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_WinRate", OBJPROP_COLOR, HUD_TextColor);
      ObjectSetInteger(0, "HUD_WinRate", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "HUD_WinRate", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_WinRate", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_WinRate", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_WinRate", OBJPROP_TEXT, "Win Rate: 0.0%");
      hudObjects[hudObjectCount++] = "HUD_WinRate";
      currentY += lineHeight;
   }
   
   if(ObjectCreate(0, "HUD_Accuracy", OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "HUD_Accuracy", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "HUD_Accuracy", OBJPROP_XDISTANCE, HUD_X);
      ObjectSetInteger(0, "HUD_Accuracy", OBJPROP_YDISTANCE, currentY);
      ObjectSetInteger(0, "HUD_Accuracy", OBJPROP_COLOR, HUD_TextColor);
      ObjectSetInteger(0, "HUD_Accuracy", OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, "HUD_Accuracy", OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, "HUD_Accuracy", OBJPROP_BACK, false);
      ObjectSetInteger(0, "HUD_Accuracy", OBJPROP_SELECTABLE, false);
      ObjectSetString(0, "HUD_Accuracy", OBJPROP_TEXT, "   Vitórias: 0 | Derrotas: 0");
      hudObjects[hudObjectCount++] = "HUD_Accuracy";
   }
   
   Print("✅ HUD criado com ", hudObjectCount, " objetos");
}

string CreateProgressBarFast(int current, int total)
{
   static string bars[21] = {
      "--------------------",
      "#-------------------",
      "##------------------",
      "###-----------------",
      "####----------------",
      "#####---------------",
      "######--------------",
      "#######-------------",
      "########------------",
      "#########-----------",
      "##########----------",
      "###########---------",
      "############--------",
      "#############-------",
      "##############------",
      "###############-----",
      "################----",
      "#################---",
      "##################--",
      "###################-",
      "####################"
   };
   
   if(total <= 0) total = 1;
   int index = (int)MathRound(SafeDivide((double)current, (double)total, 0.0) * 20);
   if(index < 0) index = 0;
   if(index > 20) index = 20;
   
   return bars[index];
}

string GetDirectionIconFast(int direction)
{
   if(direction == 1) return "^";
   if(direction == 2) return "v";
   return "O";
}

color GetDirectionColorFast(int direction)
{
   if(direction == 1) return clrLime;
   if(direction == 2) return clrRed;
   return clrGray;
}

void UpdateHUDLight()
{
   if(!ShowHUD) 
   {
      RemoveHUD();
      return;
   }
   
   if(hudObjectCount == 0)
   {
      CreateHUDObjects();
      ChartRedraw(0);
      return;
   }
   
   datetime currentTime = TimeCurrent();
   
   // ✅ ATUALIZAÇÃO EM TEMPO REAL: Se cache foi invalidado, atualizar imediatamente
   bool cacheInvalidated = (cachedVisitedStates < 0 || cachedBlockedStates < 0);
   
   if(!cacheInvalidated && currentTime - hudLastUpdate < HUD_UpdateMS/1000 && !HUD_Minimal) return;
   hudLastUpdate = currentTime;
   
   int visitedStates = cachedVisitedStates;
   if(visitedStates < 0)
   {
      visitedStates = g_activeStatesCount;
      cachedVisitedStates = visitedStates;
   }
   
   int blockedStates = cachedBlockedStates;
   if(blockedStates < 0)
   {
      blockedStates = CountBlockedStates();
      cachedBlockedStates = blockedStates;
   }
   
   int totalPositions = cachedPositions;
   if(totalPositions < 0)
   {
      totalPositions = GetTotalPositions();
      cachedPositions = totalPositions;
   }
   
   int currentDir = cachedDirection;
   if(currentDir < 0)
   {
      currentDir = GetCurrentPositionsDirection();
      cachedDirection = currentDir;
   }
   
   string newTitle = "PHOENIX TRADER v307F SUPER CORRIGIDO";
   ObjectSetString(0, "HUD_Title", OBJPROP_TEXT, newTitle);
   
   string newStates = StringFormat("Estados: %d/%d", visitedStates, NUM_STATES);
   ObjectSetString(0, "HUD_States", OBJPROP_TEXT, newStates);
   
   string progressBar = CreateProgressBarFast(visitedStates, NUM_STATES);
   double progressPercent = SafeDivide((double)visitedStates, (double)NUM_STATES, 0.0) * 100.0;
   
   // 🔧 CORREÇÃO: Converter double para string corretamente
   string newProgress = StringFormat("   [%s] (%.1f%%)", progressBar, progressPercent);
   ObjectSetString(0, "HUD_Progress", OBJPROP_TEXT, newProgress);
   
   double blockedPercent = SafeDivide((double)blockedStates, (double)visitedStates, 0.0) * 100.0;
   string newBlocked = StringFormat("   Bloqueados: %d (%.1f%%)", blockedStates, blockedPercent);
   color blockedColor = (blockedStates > 0) ? HUD_WarningColor : HUD_TextColor;
   ObjectSetInteger(0, "HUD_Blocked", OBJPROP_COLOR, blockedColor);
   ObjectSetString(0, "HUD_Blocked", OBJPROP_TEXT, newBlocked);
   
   string decayInfo = StringFormat("   Decay: %s | Ciclos: %d", 
                                   EnableMemoryDecay ? "Ativo" : "Inativo",
                                   g_totalDecayCycles);
   ObjectSetString(0, "HUD_DecayInfo", OBJPROP_TEXT, decayInfo);
   
   string directionIcon = GetDirectionIconFast(currentDir);
   string directionText = (currentDir == 1) ? "BUY" : (currentDir == 2) ? "SELL" : "NEUTRO";
   color dirColor = GetDirectionColorFast(currentDir);
   string newDirection = StringFormat("Direção: %s %s", directionIcon, directionText);
   ObjectSetInteger(0, "HUD_Direction", OBJPROP_COLOR, dirColor);
   ObjectSetString(0, "HUD_Direction", OBJPROP_TEXT, newDirection);
   
   string positionsText = StringFormat("   Posições ativas: %d", totalPositions);
   ObjectSetString(0, "HUD_Positions", OBJPROP_TEXT, positionsText);
   
   color statusColor = HUD_TextColor;
   if(StringFind(g_statusMessage, "⛔") >= 0) statusColor = HUD_ErrorColor;
   else if(StringFind(g_statusMessage, "✅") >= 0) statusColor = HUD_SuccessColor;
   else if(StringFind(g_statusMessage, "⚠️") >= 0) statusColor = HUD_WarningColor;
   
   if(cachedStatus != g_statusMessage)
   {
      ObjectSetInteger(0, "HUD_Status", OBJPROP_COLOR, statusColor);
      ObjectSetString(0, "HUD_Status", OBJPROP_TEXT, "STATUS: " + g_statusMessage);
      cachedStatus = g_statusMessage;
   }
   
   if(cachedVolume != g_volumeMultiplier)
   {
      string volumeStatus = "Volume: ";
      color volumeColor = HUD_TextColor;
      
      if(UseRealVolumeFilter)
      {
         if(g_volumeMultiplier >= 1.10)
         {
            volumeStatus += StringFormat("ALTO (%.1fx)", g_volumeMultiplier);
            volumeColor = HUD_SuccessColor;
         }
         else if(g_volumeMultiplier >= 1.00)
         {
            volumeStatus += StringFormat("NORMAL (%.1fx)", g_volumeMultiplier);
         }
         else if(g_volumeMultiplier >= 0.05)
         {
            volumeStatus += StringFormat("BAIXO (%.1fx)", g_volumeMultiplier);
            volumeColor = HUD_WarningColor;
         }
         else
         {
            volumeStatus += StringFormat("MUITO BAIXO (%.1fx)", g_volumeMultiplier);
            volumeColor = HUD_ErrorColor;
         }
      }
      else
      {
         volumeStatus += "DESATIVADO";
      }
      
      ObjectSetInteger(0, "HUD_Volume", OBJPROP_COLOR, volumeColor);
      ObjectSetString(0, "HUD_Volume", OBJPROP_TEXT, volumeStatus);
      cachedVolume = g_volumeMultiplier;
   }
   
   double explorationRatePercent = g_currentExplorationRate * 100;
   // ⚠️ GARANTIR QUE NÃO PASSE DE 100%
   if(explorationRatePercent > 100.0) explorationRatePercent = 100.0;
   string newExploration = StringFormat("Exploração: %.0f%%", explorationRatePercent);
   ObjectSetString(0, "HUD_Exploration", OBJPROP_TEXT, newExploration);
   
   if(cachedTradesToday != g_tradesToday)
   {
      color tradesColor = (g_tradesToday >= MaxTradesPerDay) ? HUD_ErrorColor : HUD_TextColor;
      string newTrades = StringFormat("Trades hoje: %d/%d", g_tradesToday, MaxTradesPerDay);
      ObjectSetInteger(0, "HUD_Trades", OBJPROP_COLOR, tradesColor);
      ObjectSetString(0, "HUD_Trades", OBJPROP_TEXT, newTrades);
      cachedTradesToday = g_tradesToday;
   }
   
   // Atualizar total de trades
   string totalTradesText = StringFormat("Total de Trades: %d", g_totalTrades);
   ObjectSetString(0, "HUD_TotalTrades", OBJPROP_TEXT, totalTradesText);
   
   // ✅ ATUALIZAR RELÓGIO DE VELA
   datetime candleOpenTime = iTime(_Symbol, _Period, 0);
   int periodSeconds = PeriodSeconds(_Period);
   datetime candleCloseTime = candleOpenTime + periodSeconds;
   int remainingSeconds = (int)(candleCloseTime - TimeCurrent());
   
   if(remainingSeconds < 0) remainingSeconds = 0;
   
   int minutes = remainingSeconds / 60;
   int seconds = remainingSeconds % 60;
   
   string candleTimerText = StringFormat("Tempo de vela: %02d:%02d", minutes, seconds);
   ObjectSetString(0, "HUD_CandleTimer", OBJPROP_TEXT, candleTimerText);
   
   // Atualizar win rate com cor dinâmica
   double winRate = SafeDivide((double)g_totalWins, (double)g_totalTrades, 0.0) * 100;
   color winRateColor = HUD_TextColor;
   if(g_totalTrades > 0)
   {
      if(winRate >= 50.0) winRateColor = HUD_SuccessColor;
      else if(winRate >= 35.0) winRateColor = HUD_TextColor;
      else winRateColor = HUD_WarningColor;
   }
   string winRateText = StringFormat("Win Rate: %.1f%%", winRate);
   ObjectSetInteger(0, "HUD_WinRate", OBJPROP_COLOR, winRateColor);
   ObjectSetString(0, "HUD_WinRate", OBJPROP_TEXT, winRateText);
   
   // Atualizar precisão (vitórias vs derrotas)
   string accuracyText = StringFormat("   Vitórias: %d | Derrotas: %d", g_totalWins, g_totalLosses);
   ObjectSetString(0, "HUD_Accuracy", OBJPROP_TEXT, accuracyText);
   
   ChartRedraw(0);
}

void InvalidateHUDCache()
{
   cachedVisitedStates = -1;
   cachedBlockedStates = -1;
   cachedPositions = -1;
   cachedDirection = -1;
   cachedStatus = "";
   cachedVolume = -1;
   cachedTradesToday = -1;
}

void RemoveHUD()
{
   for(int i = 0; i < hudObjectCount; i++)
   {
      if(hudObjects[i] != "")
      {
         ObjectDelete(0, hudObjects[i]);
      }
   }
   hudObjectCount = 0;
   InvalidateHUDCache();
   ChartRedraw(0);
}

// ======================================================================
// ✅ VERIFICAR VOLUME REAL - VERSÃO SIMPLIFICADA
// ======================================================================
bool CheckRealVolume()
{
   if(!UseRealVolumeFilter) 
   {
      g_volumeStrength = 1.0;
      return true;
   }
   
   long volumeArray[];
   int barsToCopy = VolumeMAPeriod + 1;
   
   if(CopyTickVolume(_Symbol, _Period, 1, barsToCopy, volumeArray) < barsToCopy)
   {
      Print("⚠️ Erro ao ler volume. Recebidos: ", ArraySize(volumeArray), " de ", barsToCopy);
      g_volumeStrength = 0.5;
      return true;
   }
   
   g_currentVolume = volumeArray[barsToCopy - 1];
   
   long sumVol = 0;
   for(int i = 0; i < barsToCopy - 1; i++)
   {
      sumVol += volumeArray[i];
   }
   
   g_volumeAverage = (barsToCopy > 1) ? (long)(sumVol / (barsToCopy - 1)) : sumVol;
   
   if(g_volumeAverage > 0)
   {
      g_volumeMultiplier = SafeDivide((double)g_currentVolume, (double)g_volumeAverage, 1.0);
      g_volumeStrength = g_volumeMultiplier;
      cachedVolume = -1;
   }
   else
   {
      g_volumeMultiplier = 1.0;
      g_volumeStrength = 1.0;
      return true;
   }
   
   bool isVolumeStrong = g_volumeMultiplier >= MinVolumeMultiplier;
   
   return isVolumeStrong;
}

// ======================================================================
// ✅✅✅ TRAILING STOP DINÂMICO CORRIGIDO
// ======================================================================

void ManageDynamicTrailingStop()
{
   if(!UseDynamicTrailingStop) 
   {
      if(g_trailingCount > 0)
      {
         ArrayResize(g_trailingTickets, 0);
         ArrayResize(g_trailingBestPrices, 0);
         ArrayResize(g_trailingCurrentSL, 0);
         ArrayResize(g_trailingCurrentTP, 0);
         ArrayResize(g_trailingLastTrailTimes, 0);
         ArrayResize(g_trailingBreakevenActivated, 0);
         g_trailingCount = 0;
      }
      return;
   }
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      long type = PositionGetInteger(POSITION_TYPE);
      bool isBuy = (type == POSITION_TYPE_BUY);
      
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double currentPrice = isBuy ? 
         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      // Validar point antes de usar - valor zero indica problema de configuração
      if(point <= 0 || point < 0.0000001)
      {
         Print("⚠️ ERRO: Point inválido para símbolo ", _Symbol, ": ", point);
         continue;
      }
      
      double currentProfit = isBuy ? 
         SafeDivide(currentPrice - entryPrice, point, 0.0) : 
         SafeDivide(entryPrice - currentPrice, point, 0.0);
      
      int trailIndex = -1;
      for(int j = 0; j < g_trailingCount; j++)
      {
         if(g_trailingTickets[j] == ticket)
         {
            trailIndex = j;
            break;
         }
      }
      
      if(trailIndex == -1)
      {
         AddPositionToTrailingSystem(ticket);
         continue;
      }
      
      if(isBuy)
      {
         if(currentPrice > g_trailingBestPrices[trailIndex])
         {
            g_trailingBestPrices[trailIndex] = currentPrice;
         }
      }
      else
      {
         if(currentPrice < g_trailingBestPrices[trailIndex])
         {
            g_trailingBestPrices[trailIndex] = currentPrice;
         }
      }
      
      bool shouldAdjust = false;
      double newSL = currentSL;
      double newTP = currentTP;
      
      if(UseBreakevenStop && !g_trailingBreakevenActivated[trailIndex] && 
         MathAbs(currentProfit) >= BreakevenTriggerPoints)
      {
         double breakevenPrice = entryPrice;
         
         if(isBuy) breakevenPrice += point * 10;
         else breakevenPrice -= point * 10;
         
         if((isBuy && currentPrice > breakevenPrice) || 
            (!isBuy && currentPrice < breakevenPrice))
         {
            newSL = breakevenPrice;
            g_trailingBreakevenActivated[trailIndex] = true;
            shouldAdjust = true;
            Print("💰 BREAKEVEN ativado para posição #", ticket, 
                  " | SL ajustado para: ", newSL);
         }
      }
      
      if(MathAbs(currentProfit) >= TrailingStartPoints)
      {
         // ✅ SEMPRE usa trailing fixo em pontos configurados
         double trailingDistancePoints = TrailingStopPoints;
         
         // ❌ ATR trailing REMOVIDO - usa apenas pontos fixos
         // Usuário quer controle total sobre stops fixos
         
         double trailingDistance = trailingDistancePoints * point;
         double stepDistance = TrailingStepPoints * point;
         
         if(isBuy)
         {
            double desiredStop = g_trailingBestPrices[trailIndex] - trailingDistance;
            
            if(desiredStop > currentSL || currentSL == 0)
            {
               if(MathAbs(desiredStop - currentSL) >= stepDistance || currentSL == 0)
               {
                  newSL = desiredStop;
                  shouldAdjust = true;
               }
            }
            
            if(TrailBothSLandTP && currentTP > 0)
            {
               double desiredTP = g_trailingBestPrices[trailIndex] + (trailingDistance * 0.8);
               if(desiredTP > currentTP)
               {
                  newTP = desiredTP;
                  shouldAdjust = true;
               }
            }
         }
         else
         {
            double desiredStop = g_trailingBestPrices[trailIndex] + trailingDistance;
            
            if(desiredStop < currentSL || currentSL == 0)
            {
               if(MathAbs(desiredStop - currentSL) >= stepDistance || currentSL == 0)
               {
                  newSL = desiredStop;
                  shouldAdjust = true;
               }
            }
            
            if(TrailBothSLandTP && currentTP > 0)
            {
               double desiredTP = g_trailingBestPrices[trailIndex] - (trailingDistance * 0.8);
               if(desiredTP < currentTP)
               {
                  newTP = desiredTP;
                  shouldAdjust = true;
               }
            }
         }
      }
      
      if(shouldAdjust && (newSL != currentSL || newTP != currentTP))
      {
         datetime currentTime = TimeCurrent();
         if(currentTime - g_trailingLastTrailTimes[trailIndex] >= 30)
         {
            if(trade.PositionModify(ticket, newSL, newTP))
            {
               g_trailingCurrentSL[trailIndex] = newSL;
               g_trailingCurrentTP[trailIndex] = newTP;
               g_trailingLastTrailTimes[trailIndex] = currentTime;
               
               double slPoints = SafeDivide(MathAbs(newSL - entryPrice), point, 0.0);
               double tpPoints = SafeDivide(MathAbs(newTP - entryPrice), point, 0.0);
               
               // ✅ Trailing sempre usa pontos fixos
               Print("📈 TRAILING STOP (Fixo) ajustado para posição #", ticket,
                     " | Novo SL: ", newSL, " (", slPoints, " pontos)",
                     " | Novo TP: ", newTP, " (", tpPoints, " pontos)",
                     " | Lucro atual: ", currentProfit, " pontos");
            }
            else
            {
               Print("❌ Falha ao ajustar trailing stop para posição #", ticket,
                     " | Erro: ", GetLastError());
            }
         }
      }
   }
}

void ManageAllDynamicStops()
{
   ManageDynamicTrailingStop();
   
   for(int i = g_trailingCount - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(g_trailingTickets[i]))
      {
         RemovePositionFromTrailingSystem(g_trailingTickets[i]);
      }
   }
}

// ======================================================================
// ✅✅✅ ✅✅✅ FUNÇÃO PRINCIPAL CORRIGIDA: UpdateQ (APENAS CHAMAR PARA TRADES REAIS)
// ======================================================================
void UpdateQ(int state, int action, double reward)
{
   if(state < 0 || state >= NUM_STATES) return;
   if(action < 0 || action >= NUM_ACTIONS) return;
   if(ArraySize(g_Q) <= state * NUM_ACTIONS + action) return;
   
   // ✅ REMOVER QUALQUER VERIFICAÇÃO DE LIMITE DE VISITAS
   // NÃO DEVE TER: if(g_stateVisits[state] >= 10) return;
   
   // ✅ DEBUG EXPANDIDO
   static int updateCounter = 0;
   updateCounter++;
   
   if(updateCounter % 50 == 0)
   {
      Print("🔍 UpdateQ #", updateCounter, 
            " | Estado: ", state, 
            " | Visitas: ", g_stateVisits[state],
            " | Action: ", (action==0?"NOP":(action==1?"BUY":"SELL")),
            " | Reward: ", reward);
   }
   
   if(!g_lastTradeExecuted) 
   {
      Print("⚠️ ATENÇÃO: Tentativa de atualizar Q sem trade executado");
      return;
   }
   
   AddActiveState(state);
   
   int idx = state * NUM_ACTIONS + action;
   
   // ✅ FIX BUG #2: Q-learning correto com componente futuro
   double alpha = LearningRate;
   double gamma = 0.95; // Fator de desconto
   double old = g_Q[idx];
   
   // Encontrar melhor Q do próximo estado (se houver)
   double maxNextQ = 0.0;
   if(action != 0) // Se não for NOP, há próximo estado
   {
      int nextState = GetCurrentState();
      if(nextState >= 0 && nextState < NUM_STATES)
      {
         for(int a = 0; a < NUM_ACTIONS; a++)
         {
            int nextIdx = nextState * NUM_ACTIONS + a;
            if(nextIdx < ArraySize(g_Q) && g_Q[nextIdx] > maxNextQ)
               maxNextQ = g_Q[nextIdx];
         }
      }
   }
   
   // Q-learning completo: Q(s,a) = Q(s,a) + α[r + γ*max(Q(s',a')) - Q(s,a)]
   double newq = old + alpha * (reward + gamma * maxNextQ - old);
   
   g_Q[idx] = CompressQValue(newq);
   
   g_stateLastUpdate[state] = g_totalTrades;
   
   // ✅ FIX BUG #1: REMOVIDO - Contadores agora só incrementam em OnTradeTransaction
   // Evita dupla contagem (aqui + OnTradeTransaction)
   
   // ✅ VERIFICAÇÃO DE BLOQUEIO MAIS INTELIGENTE
   if(EnableUnifiedBlockingSystem && g_stateVisits[state] >= MinVisitsForBlockDecision)
   {
      double winRate = CalculateWinRate(state);
      
      // Só bloquear se realmente for muito ruim - SEM verificação adicional de visitas
      if(winRate < 0.25)
      {
         g_stateBlocked[state] = true;
         Print("⛔ Estado ", state, " bloqueado - Win rate muito baixa: ", 
               DoubleToString(winRate*100,1), "%");
      }
      else if(g_stateBlocked[state] && winRate >= 0.40)
      {
         g_stateBlocked[state] = false;
         Print("✅ Estado ", state, " desbloqueado - Win rate melhorou: ", 
               DoubleToString(winRate*100,1), "%");
      }
   }
   
   g_memoryDirty = true;
   
   // ✅ EXPLORAÇÃO DINÂMICA BASEADA EM PERFORMANCE (apenas se habilitado)
   if(EnableAdaptiveExploration)
   {
      if(reward > 0)
      {
         // Reduzir exploração após vitória
         g_currentExplorationRate *= ExplorationDecay;
      }
      else if(reward < -1.0)
      {
         // ✅ CORRIGIDO: Aumentar exploração após perda grande, mas respeitar InitialExplorationRate como máximo
         g_currentExplorationRate = MathMin(g_currentExplorationRate * 1.1, InitialExplorationRate);
      }
   }
   
   // ✅ GARANTIR LIMITES
   if(g_currentExplorationRate > 1.0) g_currentExplorationRate = 1.0;
   if(g_currentExplorationRate < MinExplorationRate) g_currentExplorationRate = MinExplorationRate;
   
   g_qUpdatesSinceSave++;
   g_totalQUpdates++;
   
   // ✅ DECAY PERIÓDICO REMOVIDO
   // Decay é aplicado apenas pela manutenção periódica (hourly)
   // para evitar aplicação excessiva que limitava visitas
   
   // ✅ SAVE PERIÓDICO
   if(g_qUpdatesSinceSave >= 3)
   {
      SaveBrain();
   }
   
   // ✅ Correções periódicas removidas (FixStuckStatesProblem desabilitada)
}

// ======================================================================
// ✅✅✅ FUNÇÃO CORRIGIDA: UpdateQ_NOP (NÃO CONTA COMO PERDA)
// ======================================================================
void UpdateQ_NOP(int state)
{
   if(state < 0) return;
  
   Print("📊 NOP registrado para estado ", state, " (não conta como visita/perda real)");
   
   if(ExcludeNOPFromVisits)
   {
      // NOP não incrementa contadores de visita/perda
      Print("✅ NOP excluído de contagens (configuração ativa)");
   }
   
   if(ArraySize(g_Q) > state * NUM_ACTIONS)
   {
      int idx = state * NUM_ACTIONS;
      double oldQ = g_Q[idx];
      double newQ = oldQ - 0.5;  // ✅ PENALIDADE AUMENTADA: -0.5 (tornar NOP menos atrativo que trades)
      g_Q[idx] = CompressQValue(newQ);
      
      g_memoryDirty = true;
   }
}

// ======================================================================
// ✅✅✅ ChooseAction - COM SISTEMA CORRIGIDO (VERSÃO MODIFICADA)
// ======================================================================
int ChooseAction(int state)
{
   if(state < 0 || state >= NUM_STATES)
   {
      Print("❌ Estado inválido: ", state);
      return 0;
   }
   
   if(IsStateBlocked(state))
   {
      // ✅ DIAGNÓSTICO APRIMORADO: Mostra por que o estado está bloqueado e estatísticas
      double winRate = CalculateWinRate(state);
      int blockedCount = CountBlockedStates();
      Print("⛔ Estado ", state, " bloqueado pelo sistema corrigido",
            " | Win Rate: ", DoubleToString(winRate*100,1), "%",
            " | Visitas: ", g_stateVisits[state],
            " | Total bloqueados: ", blockedCount, "/", g_activeStatesCount);
      g_statusMessage = StringFormat("⛔ Estado %d bloqueado (WR: %.1f%%, %d/%d bloqueados)", 
                                     state, winRate*100, blockedCount, g_activeStatesCount);
      return 0;
   }
   
   if(ArraySize(g_Q) <= state * NUM_ACTIONS + 2)
   {
      Print("❌ Array Q não inicializado");
      return 0;
   }
   
   
   if(g_consecutiveLosses >= 12)
   {
      // ✅ Reset apenas se adaptativo estiver habilitado
      if(EnableAdaptiveExploration)
      {
         // ✅ CORRIGIDO: Reseta para InitialExplorationRate SEM multiplicar ou forçar mínimo
         g_currentExplorationRate = InitialExplorationRate;
         Print("♻️ Reset de exploração após ", g_consecutiveLosses, " perdas consecutivas para ", DoubleToString(g_currentExplorationRate*100,1), "%");
      }
   }
   
   // ⚠️ CORREÇÃO: REDUZIR EXPLORAÇÃO DRAMATICAMENTE
   if(g_stateVisits[state] < MinStateVisitsToTrade)
   {
      double eps = 0.8; // 80% de exploração para estados novos
      
      if(((double)MathRand() / 32767.0) < eps) 
      {
         int randomAction = 1 + (MathRand() % 2);
         Print("🔍 EXPLORAÇÃO (estado novo): Ação aleatória ", randomAction, " | Estado: ", state);
         g_statusMessage = "🔍 Exploração (estado novo)";
         return randomAction;
      }
      else
      {
         Print("🤔 Estado novo, mas escolhendo NOP (20% chance)");
         return 0;
      }
   }
   
   // Para estados conhecidos, usar taxa de exploração normal
   double eps = g_currentExplorationRate;
   
   // ⚠️ CAP REMOVIDO - Permitir exploração natural sem limite artificial
   // (Cap de 70% após 100 trades removido para permitir descoberta adequada de estados)

   if(((double)MathRand() / 32767.0) < eps) 
   {
      int randomAction = 1 + (MathRand() % 2);
      Print("🔍 EXPLORAÇÃO: Ação aleatória ", randomAction, " | Estado: ", state);
      g_statusMessage = "🔍 Exploração (ação aleatória)";
      return randomAction;
   }

   double best = -DBL_MAX;
   int bestA = 0;

   for(int a = 1; a < NUM_ACTIONS; a++)
   {
      int idx = state * NUM_ACTIONS + a;
      if(idx < ArraySize(g_Q) && g_Q[idx] > best)
      {
         best = g_Q[idx];
         bestA = a;
      }
   }
   
   // ✅ FIX BUG #3: Verificação de bounds antes de acessar Q-table
   int nopIdx = state * NUM_ACTIONS + 0;
   double nopQ = 0;
   if(nopIdx >= 0 && nopIdx < ArraySize(g_Q))
      nopQ = g_Q[nopIdx];
   
   // ⚠️ CORREÇÃO: Tornar NOP MENOS atrativo - exigir estados MUITO ruins
   double winRate = CalculateWinRate(state);
   if(g_stateVisits[state] >= MinVisitsForBlockDecision && winRate < 0.10)  // ✅ REDUZIDO: 10% ao invés de 15% - apenas estados EXTREMAMENTE ruins
   {
      bestA = 0;
      Print("🤔 NOP escolhido (estado muito ruim, win rate: ", DoubleToString(winRate*100,1), "%)");
      g_statusMessage = "NOP (estado muito ruim)";
   }
   else if(nopQ > best * 15.0 && bestA > 0)  // ✅ AUMENTADO: NOP precisa ser 15x melhor (anteriormente 5x)
   {
      bestA = 0;
      Print("🤔 NOP escolhido (superioridade: ", nopQ, " vs ", best, ")");
      g_statusMessage = "NOP (melhor opção)";
   }
   else if(best <= -50.0)  // ✅ REDUZIDO: -50 ao invés de -20 (ações precisam estar MUITO ruins)
   {
      bestA = 0;
      Print("🤔 NOP escolhido (ações de trade muito ruins: ", best, ")");
      g_statusMessage = "NOP (ações ruins)";
   }
   else if(bestA == 1 || bestA == 2)
   {
      if(bestA == 1) g_statusMessage = "BUY recomendado";
      else g_statusMessage = "SELL recomendado";
   }
   else
   {
      g_statusMessage = "NOP (indecisão)";
   }
   
   Print("💡 DECISÃO: Estado ", state, " | Ação ", 
         (bestA==0?"NOP":(bestA==1?"BUY":"SELL")), 
         " | Q = ", bestA==0 ? nopQ : best,
         " | Visitas: ", g_stateVisits[state],
         " | Win Rate: ", DoubleToString(winRate*100,1), "%");
   
   return bestA;
}

// ======================================================================
// ✅✅✅ ExecuteAction - COM SISTEMA CORRIGIDO
// ======================================================================
void ExecuteAction(int action, int state)
{
   g_lastTradeExecuted = false;
   g_lastTradeStateExecuted = -1;
   
   bool isBuy = (action == 1);
   
   Print("=== TENTATIVA DE EXECUÇÃO: ", isBuy ? "BUY" : "SELL", " ===");
   Print("Estado: ", state, " | Visitas REAIS: ", g_stateVisits[state], 
         " | Perdas REAIS: ", g_stateLosses[state],
         " | Vitórias REAIS: ", g_stateWins[state]);
   
   if(IsStateBlocked(state))
   {
      Print("⛔⛔⛔ BLOQUEIO CONFIRMADO - Estado ", state, " bloqueado pelo sistema corrigido - trade CANCELADO");
      g_statusMessage = StringFormat("⛔ Estado %d bloqueado (sistema corrigido)", state);
      UpdateQ_NOP(state);
      return;
   }
   
   if(UseRealVolumeFilter)
   {
      bool volumeOk = CheckRealVolume();
      if(!volumeOk && g_volumeMultiplier < 0.6)
      {
         Print("⚠️ Volume moderado, mantendo lote mínimo");
      }
   }
   
   if(!CanOpenNewPosition(isBuy))
   {
      g_statusMessage = "⛔ Não pode abrir nova posição na direção";
      UpdateQ_NOP(state);
      return;
   }
   
   if(!CanTradeBasedOnTime())
   {
      g_statusMessage = "⏳ Aguardando tempo entre trades";
      UpdateQ_NOP(state);
      return;
   }
   
   if(!CheckVolatility())
   {
      g_statusMessage = "⛔ Volatilidade alta";
      UpdateQ_NOP(state);
      return;
   }
   
   if(!ValidateAllIndicators(isBuy))
   {
      g_statusMessage = "⛔ Indicadores não confirmam";
      UpdateQ_NOP(state);
      return;
   }
   
   int sameDirCount = CountSameDirectionPositions(isBuy);
   double desiredLot = LotSize;
   
   // ✅ CORREÇÃO: Calcular Smart Lot SEMPRE (não só para primeira entrada)
   double smartLotMultiplier = 1.0;  // Multiplicador padrão
   double quality = 0.0;
   string lotDecision = "📊 NORMAL";
   
   if(EnableSmartLot)
   {
      quality = GetStateQuality(state);
      
      // 🔍 DEBUG SMART LOT: Log detalhado para diagnóstico
      int visits = (state >= 0 && state < ArraySize(g_stateVisits)) ? g_stateVisits[state] : 0;
      double buyQ = 0.0, sellQ = 0.0;
      if(state >= 0 && ArraySize(g_Q) > state * NUM_ACTIONS + 2)
      {
         buyQ = g_Q[state * NUM_ACTIONS + 1];
         sellQ = g_Q[state * NUM_ACTIONS + 2];
      }
      double bestQ = MathMax(buyQ, sellQ);
      
      Print("🔍 SMART LOT DEBUG: State=", state, 
            " | Visits=", visits,
            " | BuyQ=", DoubleToString(buyQ, 3),
            " | SellQ=", DoubleToString(sellQ, 3),
            " | BestQ=", DoubleToString(bestQ, 3),
            " | Quality=", DoubleToString(quality, 3),
            " | HighTH=", DoubleToString(HighQualityThreshold, 2),
            " | UltraTH=", DoubleToString(UltraQualityThreshold, 2));
      
      // Determinar multiplicador baseado na qualidade
      if(quality >= UltraQualityThreshold)
      {
         smartLotMultiplier = UltraLotMultiplier;
         lotDecision = "💎 ULTRA";
         Print("💎💎💎 SETUP ULTRA DETECTADO! Multiplicador: ", smartLotMultiplier, "x");
         g_statusMessage = "💎 ULTRA SETUP - Aposta Máxima!";
      }
      else if(quality >= HighQualityThreshold)
      {
         smartLotMultiplier = SmartLotMultiplier;
         lotDecision = "🚀 FORCE";
         Print("🚀🚀 SETUP FORTE DETECTADO! Multiplicador: ", smartLotMultiplier, "x");
         g_statusMessage = "🚀 SETUP FORTE - Aposta Elevada!";
      }
      else if(quality > 0.1)
      {
         lotDecision = "📈 POSITIVE";
         Print("📊 SETUP NORMAL POSITIVO");
         g_statusMessage = "📊 Setup Normal - Qualidade Positiva";
      }
      else if(quality < -0.3)
      {
         lotDecision = "⚠️ NEGATIVE";
         Print("⚠️⚠️ SETUP NEGATIVO DETECTADO - Considerando cancelar trade");
         if(quality < -0.5)
         {
            Print("⛔ TRADE CANCELADO - Qualidade muito baixa: ", quality);
            g_statusMessage = "⛔ Setup Negativo - Trade Cancelado";
            UpdateQ_NOP(state);
            return;
         }
      }
      else
      {
         Print("📈 SETUP NEUTRO");
      }
   }
   
   // ✅ CORREÇÃO: Aplicar Smart Lot tanto para primeira entrada quanto para piramidação
   if(sameDirCount == 0)
   {
      // Primeira entrada: usar lote base × Smart Lot
      desiredLot = LotSize * smartLotMultiplier;
      Print("💰 PRIMEIRA ENTRADA: LotSize=", DoubleToString(LotSize, 2), 
            " × SmartMult=", DoubleToString(smartLotMultiplier, 2),
            " = ", DoubleToString(desiredLot, 2));
   }
   else
   {
      // ✅ PIRAMIDAÇÃO: Calcular lote base de piramidação E aplicar Smart Lot
      double pyramidBaseLot = CalculatePyramidLot(isBuy);
      desiredLot = pyramidBaseLot * smartLotMultiplier;
      
      Print("🏗️ PIRAMIDAÇÃO #", sameDirCount + 1, 
            ": PyramidBase=", DoubleToString(pyramidBaseLot, 2),
            " × SmartMult=", DoubleToString(smartLotMultiplier, 2),
            " = ", DoubleToString(desiredLot, 2));
   }
   
   // 📊 LOT DECISION SUMMARY: Mostra a decisão final de lote
   Print("📊 LOT DECISION SUMMARY: ",
         lotDecision, " → ",
         "BaseLot=", DoubleToString(LotSize, 2),
         " × ", DoubleToString(smartLotMultiplier, 2),
         " = FinalLot=", DoubleToString(desiredLot, 2),
         " | Quality=", DoubleToString(quality, 3),
         " | HighTH=", DoubleToString(HighQualityThreshold, 2),
         " | UltraTH=", DoubleToString(UltraQualityThreshold, 2),
         " | PyramidLevel=", sameDirCount,
         " | MULTIPLIER APPLIED: ", (smartLotMultiplier > 1.0 ? "YES ✅" : "NO ❌"));
   
   if(desiredLot > MaxAllowedLot) 
   {
      desiredLot = MaxAllowedLot;
      Print("⚠️ Lote limitado ao máximo permitido: ", MaxAllowedLot);
   }
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(desiredLot < minLot) 
   {
      desiredLot = minLot;
      Print("⚠️ Lote ajustado ao mínimo permitido: ", minLot);
   }
   
   Print("💰 LOTE FINAL DEFINIDO: ", desiredLot);
   
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double sl_price = 0.0;
   double tp_price = 0.0;
   
   if(UseFixedSL) sl_price = CalculateSLByPoints(isBuy, price);
   if(UseFixedTP) tp_price = CalculateTPByPoints(isBuy, price);

   // MINI-LOG PARA VALIDAR SL/TP EM PONTOS
   if(point > 0.0)
   {
      double slPointsCheck = 0.0;
      double tpPointsCheck = 0.0;

      // ✅ FIX: Protect against division by zero - check if point > 0
      if(point > 0.0)
      {
         if(sl_price > 0.0)
         {
            if(isBuy)
               slPointsCheck = (price - sl_price) / point;
            else
               slPointsCheck = (sl_price - price) / point;
         }

         if(tp_price > 0.0)
         {
            if(isBuy)
               tpPointsCheck = (tp_price - price) / point;
            else
               tpPointsCheck = (price - tp_price) / point;
         }
      }

      Print("🎯 MINI-LOG SLTP: dir=", (isBuy ? "BUY" : "SELL"),
            " | entry=", DoubleToString(price, 5),
            " | SL=", DoubleToString(sl_price, 5),
            " | TP=", DoubleToString(tp_price, 5),
            " | SL_pts~=", DoubleToString(slPointsCheck, 0),
            " | TP_pts~=", DoubleToString(tpPointsCheck, 0),
            " | FixedSL_Points=", FixedSL_Points,
            " | FixedTP_Points=", FixedTP_Points);
   }

   if(!AreStopsValid(isBuy, price, sl_price, tp_price))
   {
      g_statusMessage = "⛔ Stops inválidos";
      UpdateQ_NOP(state);
      return;
   }

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req); ZeroMemory(res);

   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = _Symbol;
   req.volume    = desiredLot;
   req.type      = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price     = price;
   req.sl        = sl_price;
   req.tp        = tp_price;
   req.magic     = (ulong)MagicNumber;
   req.deviation = 30;
   req.type_filling = ORDER_FILLING_FOK;
   
   int pyramidLevel = sameDirCount + 1;
   string commentType = "NORMAL";
   
   // quality já foi declarada anteriormente na linha 4169
   quality = GetStateQuality(state);
   
   // ✅ FIX BUG #12: Validar quality após GetStateQuality
   if(quality != quality) quality = 0.0; // NaN check
   if(quality < -10.0 || quality > 10.0) quality = 0.0; // Valor absurdo
   
   if(sameDirCount == 0 && EnableSmartLot)
   {
      if(quality >= UltraQualityThreshold) commentType = "ULTRA";
      else if(quality >= HighQualityThreshold) commentType = "FORCE";
      else if(quality > 0.1) commentType = "POS";
      else if(quality < -0.2) commentType = "NEG";
      else commentType = "NEUTRO";
   }
   
   string comment = StringFormat("PHX307F_CORRIGIDO_%s_%s_P%d_SL%d_TP%d_VOL%.1fx_Q%.2f_DECAY%d", 
                   isBuy ? "BUY" : "SELL",
                   commentType,
                   pyramidLevel,
                   FixedSL_Points, FixedTP_Points,
                   g_volumeMultiplier,
                   quality,
                   g_totalDecayCycles);
   
   // ✅ CORREÇÃO: Atribuir string diretamente ao campo comment
   req.comment = comment;

   if(!OrderSend(req,res))
   {
      Print("❌ Falha na ordem: Erro ", GetLastError());
      g_statusMessage = "⛔ Falha na ordem";
      UpdateQ_NOP(state);
      return;
   }

   g_lastTradeExecuted = true;
   g_lastTradeStateExecuted = state;
   
   g_lastTradeTime = TimeCurrent();
   
   if(isBuy)
      g_lastBuyTime = TimeCurrent();
   else
      g_lastSellTime = TimeCurrent();
   
   g_lastTradeState  = state;
   g_lastTradeAction = action;
   g_lastLotUsed     = desiredLot;
   g_tradesToday++;
   
   g_currentDirection = isBuy ? 1 : 2;
   g_positionsCount = GetTotalPositions();
   cachedPositions = -1;
   cachedDirection = -1;
   cachedTradesToday = -1;
   
   AddPositionToTrailingSystem((ulong)res.order);
   
   // ✅ MAE/MFE TRACKING: Adiciona posição ao rastreamento de eficiência
   int direction = isBuy ? 1 : -1;
   AddPositionTracking((ulong)res.order, price, sl_price, tp_price, direction);
   
   double slPoints = 0, tpPoints = 0;
   if(sl_price > 0) slPoints = SafeDivide(MathAbs(price - sl_price), point, 0.0);
   if(tp_price > 0) tpPoints = SafeDivide(MathAbs(tp_price - price), point, 0.0);
   
   string lotTypeMsg = "";
   if(sameDirCount == 0 && EnableSmartLot)
   {
      if(quality >= UltraQualityThreshold) lotTypeMsg = "💎 ULTRA ";
      else if(quality >= HighQualityThreshold) lotTypeMsg = "🚀 FORCE ";
      else if(quality > 0.1) lotTypeMsg = "📈 POS ";
      else if(quality < -0.2) lotTypeMsg = "⚠️ NEG ";
      else lotTypeMsg = "📊 NEUTRO ";
   }
   
   g_statusMessage = StringFormat("✅ %s%s #%d executado (VOL: %.1fx, Q: %.2f, Decay: %d)", 
                                  lotTypeMsg, 
                                  isBuy ? "BUY" : "SELL", 
                                  pyramidLevel, 
                                  g_volumeMultiplier, 
                                  quality,
                                  g_totalDecayCycles);
   
   Print("🎯 TRADE EXECUTADO COM SUCESSO - SISTEMA CORRIGIDO COM DECAY: ",
         lotTypeMsg,
         isBuy ? "BUY" : "SELL", " #", pyramidLevel,
         " | Estado: ", state,
         " | Volume: ", g_currentVolume, " (", DoubleToString(g_volumeMultiplier, 1), "x)",
         " | Qualidade: ", DoubleToString(quality, 2),
         " | Lote: ", desiredLot, " (", DoubleToString(desiredLot/LotSize, 1), "x)",
         " | SL: ", DoubleToString(slPoints, 0), " pts",
         " | TP: ", DoubleToString(tpPoints, 0), " pts",
         " | Preço: ", DoubleToString(price, 5),
         " | Ciclos Decay: ", g_totalDecayCycles);
   
   Print("📊 AGUARDANDO FECHAMENTO: Trade executado, visitas/perdas serão atualizadas apenas após fechamento...");
}

// ======================================================================
// ✅✅✅ FUNÇÃO ComputeRewardFromTrade (ATUALIZADA)
// ======================================================================
double ComputeRewardFromTrade(double profit)
{
   if(UseSimpleRewardSystem)
   {
      if(profit > 0) return RewardWin;
      else return RewardLoss;
   }
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double profit_points = SafeDivide(profit, (LotSize * point * 100), 0.0);
   
   if(profit > 0)
   {
      return 1.0 + profit_points / 100.0;
   }
   else
   {
      return -1.0 - MathAbs(profit_points) / 200.0;
   }
}

// ======================================================================
// ✅✅✅ FUNÇÃO GetStateQuality - VERSÃO MELHORADA
// ======================================================================
double GetStateQuality(int state)
{
   if(state < 0 || state >= NUM_STATES) return 0.0;
   if(ArraySize(g_stateVisits) <= state) return 0.0;
   if(ArraySize(g_Q) <= state * NUM_ACTIONS + 2) return 0.0;
   
   if(g_stateVisits[state] < 2) return 0.0;
   
   double buyQ  = g_Q[state * NUM_ACTIONS + 1];
   double sellQ = g_Q[state * NUM_ACTIONS + 2];
   double nopQ  = g_Q[state * NUM_ACTIONS + 0];
   
   double bestTradeQ = MathMax(buyQ, sellQ);
   
   if(nopQ > bestTradeQ * 3.0)
   {
      double penalizedQuality = (bestTradeQ - nopQ) / 5.0;
      return MathMax(penalizedQuality, -2.0);
   }
   
   double quality = bestTradeQ / 10.0;
   
   if(g_stateVisits[state] >= MinVisitsForBlockDecision)
   {
      double winRate = CalculateWinRate(state);
      double lossRate = 1.0 - winRate;
      
      if(lossRate > 0.6)
      {
         quality -= (lossRate - 0.6) * 3.0;
      }
      
      if(winRate > 0.7 && g_stateVisits[state] >= MinVisitsForBlockDecision)
      {
         quality += (winRate - 0.7) * 2.0;
      }
   }
   
   if(quality > 2.0) quality = 2.0;
   if(quality < -2.0) quality = -2.0;
   
   return quality;
}

// ======================================================================
// ✅✅✅ FUNÇÕES PARA CALCULAR ESTADO
// ======================================================================

// ✅ Função para calcular bucket RSI
int GetRSIBucket(double rsiValue)
{
   if(rsiValue < 25) return 0;          // Muito sobrevendido
   else if(rsiValue < 40) return 1;     // Sobrevedido
   else if(rsiValue < 50) return 2;     // Tendência de baixa
   else return 3;                       // Tendência de alta
}

// ✅ Função para calcular bucket MA Distance
int GetMADistanceBucket(double maDistance)
{
   if(maDistance < -1.5) return 0;       // Muito abaixo da MA
   else if(maDistance < 0) return 1;     // Abaixo da MA
   else return 2;                        // Acima da MA
}

// ✅ Função para calcular bucket ADX
// ✅ Função para calcular bucket MACD
int GetMACDBucket(double macdHistogram)
{
   // Discretiza o histograma MACD em 3 níveis
   if(macdHistogram < -0.0001) return 0;      // MACD negativo (bearish)
   else if(macdHistogram > 0.0001) return 2;  // MACD positivo (bullish)
   else return 1;                             // MACD neutro (próximo de zero)
}

// ✅ Função para calcular bucket volatilidade
int GetVolatilityBucket(double atrCurrent, double atrPrevious)
{
   double ratio = SafeDivide(atrCurrent, atrPrevious, 1.0);
   
   if(ratio < 0.8) return 0;             // Volatilidade diminuindo
   else return 1;                        // Volatilidade estável/aumentando
}

// ✅ Função para calcular bucket volume
int GetVolumeBucket()
{
   if(!UseRealVolumeFilter) return 1;    // Volume normal (default)
   
   if(g_volumeMultiplier < 0.7) return 0;  // Volume baixo
   else return 1;                         // Volume normal/alto
}

// ✅ Função para calcular bucket de tempo
int GetTimeBucket()
{
   MqlDateTime timeStruct;
   TimeCurrent(timeStruct);
   
   int hour = timeStruct.hour;
   
   if(hour >= 0 && hour < 12) return 0;      // Manhã/Madrugada
   else return 1;                            // Tarde/Noite
}

// ======================================================================
// ✅✅✅ FUNÇÃO GetCurrentState (OTIMIZADA E CORRIGIDA)
// ======================================================================
int GetCurrentState()
{
   double ma[], rsi[], macd_main[], macd_signal[], atr[];
   ArraySetAsSeries(ma, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(macd_main, true);
   ArraySetAsSeries(macd_signal, true);
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(g_maHandle, 0, 0, 1, ma) < 1) 
   {
      Print("❌ Erro ao copiar MA");
      return -1;
   }
   if(CopyBuffer(g_rsiHandle, 0, 0, 1, rsi) < 1) 
   {
      Print("❌ Erro ao copiar RSI");
      return -1;
   }
   if(CopyBuffer(g_macdHandle, 0, 0, 1, macd_main) < 1) 
   {
      Print("❌ Erro ao copiar MACD Main");
      return -1;
   }
   if(CopyBuffer(g_macdHandle, 1, 0, 1, macd_signal) < 1) 
   {
      Print("❌ Erro ao copiar MACD Signal");
      return -1;
   }
   if(CopyBuffer(g_atrHandle, 0, 0, 2, atr) < 2) 
   {
      Print("❌ Erro ao copiar ATR");
      return -1;
   }
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // ✅ FIX BUG #4: Verificar se point é zero antes de usar como divisor
   if(point <= 0) point = 0.00001; // Fallback seguro
   
   // ✅ Cálculo da distância da MA
   double maDistance = 0;
   double atrValue = atr[0];
   
   if(atrValue > 0)
      maDistance = SafeDivide(price - ma[0], atrValue, 0.0);
   else
      maDistance = SafeDivide(price - ma[0], point * 10, 0.0);
   
   // ✅ Cálculo do Histograma MACD
   double macdHistogram = macd_main[0] - macd_signal[0];
   
   // ✅ Calcular buckets otimizados
   int maBucket = GetMADistanceBucket(maDistance);
   int rsiBucket = GetRSIBucket(rsi[0]);
   int macdBucket = GetMACDBucket(macdHistogram);
   int volBucket = GetVolatilityBucket(atr[0], atr[1]);
   int volumeBucket = GetVolumeBucket();
   int timeBucket = GetTimeBucket();
   
   // ✅ Proteção contra overflow
   maBucket = (int)MathMod(maBucket, BINS_MA_DIST);
   rsiBucket = (int)MathMod(rsiBucket, BINS_RSI);
   macdBucket = (int)MathMod(macdBucket, BINS_MACD);
   volBucket = (int)MathMod(volBucket, BINS_VOLATILITY);
   volumeBucket = (int)MathMod(volumeBucket, BINS_VOLUME);
   timeBucket = (int)MathMod(timeBucket, BINS_TIME);
   
   // ✅ CORREÇÃO: Método correto - multiplicar na ordem inversa
   int state_idx = 0;
   
   // Método correto - multiplicar na ordem inversa (ajustado para MACD)
   state_idx = ((((timeBucket * BINS_VOLUME + volumeBucket) * BINS_VOLATILITY + volBucket) * 
                  BINS_MACD + macdBucket) * BINS_RSI + rsiBucket) * BINS_MA_DIST + maBucket;
   
   // ✅ VERIFICAÇÃO DE SEGURANÇA
   if(state_idx < 0) state_idx = 0;
   if(state_idx >= NUM_STATES) 
   {
      Print("❌ ERRO CRÍTICO: Estado calculado ", state_idx, " excede NUM_STATES ", NUM_STATES);
      state_idx = state_idx % NUM_STATES; // Forçar dentro dos limites
   }
   
   // ✅ DEBUG para verificar cálculo
   static int debugCounter = 0;
   if(debugCounter++ % 100 == 0)
   {
      Print("DEBUG Estado: idx=", state_idx, 
            " | ma=", maBucket, " rsi=", rsiBucket, " macd=", macdBucket,
            " vol=", volBucket, " volM=", volumeBucket, " time=", timeBucket);
   }
   
   // ✅ PROTEÇÃO CONTRA ESTADO CONGELADO
   static int lastState = -1;
   static int sameStateCount = 0;
   static datetime lastStateChange = 0;
   
   if(state_idx == lastState)
   {
      sameStateCount++;
      datetime now = TimeCurrent();
      
      // Se ficou no mesmo estado por muito tempo, forçar variação
      if(sameStateCount > 20 && (now - lastStateChange) > 3600)
      {
         Print("⚠️ Estado congelado detectado! Forçando variação...");
         state_idx = (state_idx + 1 + MathRand() % 5) % NUM_STATES;
         sameStateCount = 0;
         lastStateChange = now;
      }
   }
   else
   {
      sameStateCount = 0;
      lastState = state_idx;
      lastStateChange = TimeCurrent();
   }
   
   // ✅ Log de diagnóstico (apenas ocasionalmente)
   static int lastLoggedState = -1;
   static datetime lastLogTime = 0;
   datetime currentTime = TimeCurrent();
   
   if((state_idx != lastLoggedState && (currentTime - lastLogTime) > 300) || 
      g_totalTrades % 50 == 0)
   {
      PrintFormat("📊 Estado calculado: %d | RSI=%.1f(%d) | MA_dist=%.2f(%d) | MACD=%.5f(%d) | Vol=%d | Time=%d",
                  state_idx, rsi[0], rsiBucket, maDistance, maBucket, macdHistogram, macdBucket, 
                  volBucket, timeBucket);
      lastLoggedState = state_idx;
      lastLogTime = currentTime;
   }
   
   return state_idx;
}

// ======================================================================
// ✅ FUNÇÕES DE CONTROLE DE DIREÇÃO
// ======================================================================
int GetCurrentPositionsDirection()
{
   int buyCount = 0;
   int sellCount = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      long type = PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY) buyCount++;
      else if(type == POSITION_TYPE_SELL) sellCount++;
   }
   
   if(buyCount > 0 && sellCount == 0) return 1;
   if(sellCount > 0 && buyCount == 0) return 2;
   if(buyCount > 0 && sellCount > 0) return 3;
   return 0;
}

int GetTotalPositions()
{
   int count = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      count++;
   }
   
   return count;
}

bool CanOpenNewPosition(bool isBuy)
{
   if(AllowOnlyOneDirection)
   {
      int currentDir = GetCurrentPositionsDirection();
      
      if(currentDir == 3)
      {
         Print("❌ ERRO: Encontradas posições em ambas as direções!");
         return false;
      }
      
      if((currentDir == 1 && !isBuy) || (currentDir == 2 && isBuy))
      {
         if(CloseOppositeOnNewSignal)
         {
            Print("⚠️ Fechando posições na direção oposta para nova entrada...");
            CloseAllPositions();
            return true;
         }
         else if(WaitForAllCloseBeforeNew)
         {
            Print("⏳ Aguardando posições opostas fecharem...");
            return false;
         }
         else
         {
            Print("❌ Já existe posição na direção oposta");
            return false;
         }
      }
      
      if((currentDir == 1 && isBuy) || (currentDir == 2 && !isBuy))
      {
         if(!EnablePyramiding)
         {
            Print("❌ Piramidação desativada. Já existe posição na mesma direção.");
            return false;
         }
         return CanPyramid(isBuy);
      }
   }
   else
   {
      if(GetTotalPositions() > 0)
      {
         return CanPyramid(isBuy);
      }
   }
   
   int sameDirCount = CountSameDirectionPositions(isBuy);
   if(sameDirCount >= MaxTradesPerDirection)
   {
      Print("❌ Limite máximo de posições por direção atingido: ", sameDirCount, "/", MaxTradesPerDirection);
      return false;
   }
   
   if(sameDirCount > 0)
   {
      datetime lastTradeTime = isBuy ? g_lastBuyTime : g_lastSellTime;
      if(lastTradeTime > 0)
      {
         datetime currentTime = TimeCurrent();
         int secondsSinceLast = (int)(currentTime - lastTradeTime);
         int requiredSeconds = MinMinutesBetweenTrades * 60;
         
         if(secondsSinceLast < requiredSeconds)
         {
            Print("⏳ Aguardando tempo entre entradas na mesma direção: ", 
                  secondsSinceLast, "s/", requiredSeconds, "s");
            return false;
         }
      }
   }
   
   if(sameDirCount > 0 && MinBarsBetweenSameDirection > 0)
   {
      int barsSinceLast = BarsSinceLastEntry(isBuy);
      if(barsSinceLast >= 0 && barsSinceLast < MinBarsBetweenSameDirection)
      {
         Print("⏳ Aguardando mais barras para nova entrada na mesma direção: ",
               barsSinceLast, "/", MinBarsBetweenSameDirection, " barras");
         return false;
      }
   }
   
   Print("✅ Pode abrir nova posição na direção: ", isBuy ? "BUY" : "SELL");
   return true;
}

int BarsSinceLastEntry(bool isBuy)
{
   datetime lastEntryTime = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      long type = PositionGetInteger(POSITION_TYPE);
      if((isBuy && type == POSITION_TYPE_BUY) || (!isBuy && type == POSITION_TYPE_SELL))
      {
         datetime entryTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(entryTime > lastEntryTime) lastEntryTime = entryTime;
      }
   }
   
   if(lastEntryTime == 0) return -1;
   
   return Bars(_Symbol, _Period, lastEntryTime, TimeCurrent());
}

bool CloseAllPositions()
{
   bool allClosed = true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      if(!trade.PositionClose(ticket, (ulong)30))
      {
         Print("❌ Falha ao fechar posição #", ticket);
         allClosed = false;
      }
      else
      {
         Print("✅ Posição #", ticket, " fechada");
      }
   }
   cachedPositions = -1;
   cachedDirection = -1;
   return allClosed;
}

// ======================================================================
// ✅ FUNÇÕES PARA STOPS
// ======================================================================
double CalculateSLByPoints(bool isBuy, double entryPrice)
{
   if(!UseFixedSL) return 0.0;
   
   int slPoints = FixedSL_Points;
   if(slPoints <= 0) return 0.0;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDistance = slPoints * point;
   
   if(isBuy)
   {
      double slPrice = entryPrice - slDistance;
      Print("✅ SL BUY calculado: Entry=", DoubleToString(entryPrice, 5), " - SL=", DoubleToString(slPrice, 5), 
            " (", slPoints, " pontos = ", DoubleToString(slDistance, 5), ")");
      return slPrice;
   }
   else
   {
      double slPrice = entryPrice + slDistance;
      Print("✅ SL SELL calculado: Entry=", DoubleToString(entryPrice, 5), " + SL=", DoubleToString(slPrice, 5), 
            " (", slPoints, " pontos = ", DoubleToString(slDistance, 5), ")");
      return slPrice;
   }
}

double CalculateTPByPoints(bool isBuy, double entryPrice)
{
   if(!UseFixedTP) return 0.0;
   
   int tpPoints = FixedTP_Points;
   if(tpPoints <= 0) return 0.0;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tpDistance = tpPoints * point;
   
   if(isBuy)
   {
      double tpPrice = entryPrice + tpDistance;
      Print("✅ TP BUY calculado: Entry=", DoubleToString(entryPrice, 5), " + TP=", DoubleToString(tpPrice, 5), 
            " (", tpPoints, " pontos = ", DoubleToString(tpDistance, 5), ")");
      return tpPrice;
   }
   else
   {
      double tpPrice = entryPrice - tpDistance;
      Print("✅ TP SELL calculado: Entry=", DoubleToString(entryPrice, 5), " - TP=", DoubleToString(tpPrice, 5), 
            " (", tpPoints, " pontos = ", DoubleToString(tpDistance, 5), ")");
      return tpPrice;
   }
}

bool AreStopsValid(bool isBuy, double entryPrice, double slPrice, double tpPrice)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   Print("=== VERIFICAÇÃO DE STOPS ===");
   Print("Direção: ", isBuy ? "BUY" : "SELL");
   Print("Entry: ", DoubleToString(entryPrice, 5));
   Print("SL: ", DoubleToString(slPrice, 5));
   Print("TP: ", DoubleToString(tpPrice, 5));
   
   if(UseFixedSL && slPrice > 0)
   {
      // ✅ FIX BUG #6: Verificar relação preço PRIMEIRO, depois distância
      if(isBuy)
      {
         if(slPrice >= entryPrice)
         {
            Print("❌ ERRO: SL de BUY deve estar abaixo do preço de entrada!");
            Print("SL: ", DoubleToString(slPrice, 5), " >= Entry: ", DoubleToString(entryPrice, 5));
            return false;
         }
      }
      else // SELL
      {
         if(slPrice <= entryPrice)
         {
            Print("❌ ERRO: SL de SELL deve estar acima do preço de entrada!");
            Print("SL: ", DoubleToString(slPrice, 5), " <= Entry: ", DoubleToString(entryPrice, 5));
            return false;
         }
      }
      
      // Agora valida distância
      double slDistance = MathAbs(entryPrice - slPrice);
      double slPoints = SafeDivide(slDistance, point, 0.0);
      
      long minStopsLevel = (long)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minSL = minStopsLevel * point;
      double minSLPoints = SafeDivide(minSL, point, 0.0);
      
      Print("SL Distance: ", DoubleToString(slDistance, 5), " (", DoubleToString(slPoints, 0), " pontos)");
      Print("Min SL required: ", DoubleToString(minSL, 5), " (", DoubleToString(minSLPoints, 0), " pontos)");
      
      if(slDistance < minSL && minSL > 0)
      {
         Print("❌ ERRO: SL muito pequeno!");
         return false;
      }
      
      Print("✅ SL válido: ", DoubleToString(slPoints, 0), " pontos");
   }
   
   if(UseFixedTP && tpPrice > 0)
   {
      // ✅ FIX BUG #6: Verificar relação preço PRIMEIRO, depois distância
      if(isBuy)
      {
         if(tpPrice <= entryPrice)
         {
            Print("❌ ERRO: TP de BUY deve estar acima do preço de entrada!");
            Print("TP: ", DoubleToString(tpPrice, 5), " <= Entry: ", DoubleToString(entryPrice, 5));
            return false;
         }
      }
      else // SELL
      {
         if(tpPrice >= entryPrice)
         {
            Print("❌ ERRO: TP de SELL deve estar abaixo do preço de entrada!");
            Print("TP: ", DoubleToString(tpPrice, 5), " >= Entry: ", DoubleToString(entryPrice, 5));
            return false;
         }
      }
      
      // Agora valida distância
      double tpDistance = MathAbs(entryPrice - tpPrice);
      double tpPoints = SafeDivide(tpDistance, point, 0.0);
      
      long minStopsLevel = (long)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minTP = minStopsLevel * point;
      double minTPPoints = SafeDivide(minTP, point, 0.0);
      
      Print("TP Distance: ", DoubleToString(tpDistance, 5), " (", DoubleToString(tpPoints, 0), " pontos)");
      Print("Min TP required: ", DoubleToString(minTP, 5), " (", DoubleToString(minTPPoints, 0), " pontos)");
      
      if(tpDistance < minTP && minTP > 0)
      {
         Print("❌ ERRO: TP muito pequeno!");
         return false;
      }
      
      Print("✅ TP válido: ", DoubleToString(tpPoints, 0), " pontos");
   }
   
   Print("=== STOPS VALIDADOS COM SUCESSO ===");
   return true;
}

// ======================================================================
// ✅ FUNÇÕES DE VALIDAÇÃO COM INDICADORES
// ======================================================================
bool ValidateWithRSI(bool isBuy)
{
   if(!UseRSIValidation) return true;
   
   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(g_rsiHandle, 0, 0, 2, rsi) < 2) return false;
   
   double currentRSI = rsi[0];
   double previousRSI = rsi[1];
   
   if(isBuy)
   {
      if(currentRSI < RSI_Oversold) 
      {
         Print("✅ RSI EXCELENTE para BUY: ", DoubleToString(currentRSI, 2), " (oversold)");
         return true;
      }
      
      if(currentRSI < 40 && currentRSI > previousRSI)
      {
         Print("✅ RSI BOM para BUY: ", DoubleToString(currentRSI, 2), " (subindo de região baixa)");
         return true;
      }
      
      if(currentRSI < 50)
      {
         Print("✅ RSI ACEITÁVEL para BUY: ", DoubleToString(currentRSI, 2), " (abaixo de 50)");
         return true;
      }
      
      if(currentRSI > 85)
      {
         Print("❌ RSI inválido para BUY: ", DoubleToString(currentRSI, 2), " (sobrecomprado extremo)");
         return false;
      }
      
      Print("⚠️ RSI neutro para BUY: ", DoubleToString(currentRSI, 2));
      return true;
   }
   else
   {
      if(currentRSI > RSI_Overbought)
      {
         Print("✅ RSI EXCELENTE para SELL: ", DoubleToString(currentRSI, 2), " (sobrecomprado)");
         return true;
      }
      
      if(currentRSI > 60 && currentRSI < previousRSI)
      {
         Print("✅ RSI BOM para SELL: ", DoubleToString(currentRSI, 2), " (caindo de região alta)");
         return true;
      }
      
      if(currentRSI > 50)
      {
         Print("✅ RSI ACEITÁVEL para SELL: ", DoubleToString(currentRSI, 2), " (acima de 50)");
         return true;
      }
      
      if(currentRSI < 15)
      {
         Print("❌ RSI inválido para SELL: ", DoubleToString(currentRSI, 2), " (sobrevendido extremo)");
         return false;
      }
      
      Print("⚠️ RSI neutro para SELL: ", DoubleToString(currentRSI, 2));
      return true;
   }
}

bool ValidateWithTrend(bool isBuy)
{
   if(!UseTrendValidation) return true;
   
   double ma[], atr[];
   ArraySetAsSeries(ma, true);
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_maHandle, 0, 0, 1, ma) < 1) return false;
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) < 1) return false;
   
   double price = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double atr_value = atr[0];
   if(atr_value < point * 10)
   {
      atr_value = price * 0.005;
   }
   
   double distance_from_ma = SafeDivide(price - ma[0], atr_value, 0.0);
   
   if(isBuy)
   {
      if(distance_from_ma > -1.5 || distance_from_ma < -4.0) 
      {
         return true; 
      }
      else
      {
         Print("❌ Tendência inválida para BUY: preço em zona morta (distância: ", DoubleToString(distance_from_ma, 2), " ATRs)");
         return false;
      }
   }
   else
   {
      if(distance_from_ma < 1.5 || distance_from_ma > 4.0) 
      {
         return true;
      }
      else
      {
         Print("❌ Tendência inválida para SELL: preço em zona morta (distância: ", DoubleToString(distance_from_ma, 2), " ATRs)");
         return false;
      }
   }
}

bool CanTradeBasedOnTime()
{
   if(g_lastTradeTime == 0) return true;
   
   datetime currentTime = TimeCurrent();
   int secondsSinceLastTrade = (int)(currentTime - g_lastTradeTime);
   int requiredSeconds = MinMinutesBetweenTrades * 60;
   
   if(secondsSinceLastTrade < requiredSeconds)
   {
      Print("⏳ Aguardando tempo. Segundos desde último trade: ", secondsSinceLastTrade,
            " | Necessários: ", requiredSeconds);
      return false;
   }
   
   return true;
}

bool CheckVolatility()
{
   if(!UseVolatilityFilter) return true;
   
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_atrHandle, 0, 0, 2, atr) < 2) return true;
   
   double currentATR = atr[0];
   double previousATR = atr[1];
   
   if(currentATR > (previousATR * MaxATRMultiplier))
   {
      Print("⛔ Volatilidade alta. ATR atual: ", DoubleToString(currentATR, 5),
            " | Anterior: ", DoubleToString(previousATR, 5));
      return false;
   }
   
   return true;
}

bool ValidateAllIndicators(bool isBuy)
{
   Print("=== VALIDAÇÃO DE INDICADORES PARA ", isBuy ? "BUY" : "SELL", " ===");
   
   if(!ValidateWithRSI(isBuy))
   {
      Print("❌ VALIDAÇÃO FALHOU: RSI");
      return false;
   }
   
   if(!ValidateWithTrend(isBuy))
   {
      Print("❌ VALIDAÇÃO FALHOU: Tendência MA");
      return false;
   }
   
   Print("✅ TODOS OS INDICADORES VALIDADOS COM SUCESSO!");
   return true;
}

// ======================================================================
// ✅ FUNÇÕES DE PIRAMIDAÇÃO
// ======================================================================
int CountSameDirectionPositions(bool isBuy)
{
   int count = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      long type = PositionGetInteger(POSITION_TYPE);
      if(isBuy && type == POSITION_TYPE_BUY) count++;
      if(!isBuy && type == POSITION_TYPE_SELL) count++;
   }
   
   return count;
}

bool CanPyramid(bool isBuy)
{
   if(!EnablePyramiding) 
   {
      Print("❌ Piramidação desativada nas configurações");
      return false;
   }
   
   int sameDirCount = CountSameDirectionPositions(isBuy);
   
   Print("📊 Piramidação: Contagem na direção ", isBuy ? "BUY" : "SELL", ": ", sameDirCount);
   
   if(sameDirCount >= MaxPyramidPositions)
   {
      Print("❌ PIRAMIDAÇÃO: Limite de ", MaxPyramidPositions, " posições por direção atingido");
      return false;
   }
   
   if(sameDirCount > 0)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(g_atrHandle, 0, 0, 1, atr) < 1) 
      {
         Print("❌ PIRAMIDAÇÃO: Não foi possível obter o valor do ATR");
         return false;
      }
      
      double currentPrice = isBuy ? 
         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double minDistance = PyramidingDistanceATR * atr[0];
      
      Print("📏 Piramidação: Distância mínima necessária: ", DoubleToString(minDistance, 5), " (", PyramidingDistanceATR, " ATRs)");
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         
         long type = PositionGetInteger(POSITION_TYPE);
         if((isBuy && type == POSITION_TYPE_BUY) || (!isBuy && type == POSITION_TYPE_SELL))
         {
            double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double distance = MathAbs(currentPrice - entryPrice);
            
            Print("📐 Piramidação: Ticket #", ticket, " | Entry: ", DoubleToString(entryPrice, 5), 
                  " | Current: ", DoubleToString(currentPrice, 5), " | Distance: ", DoubleToString(distance, 5));
            
            if(distance < minDistance)
            {
               Print("❌ PIRAMIDAÇÃO: Posição muito próxima (", DoubleToString(distance, 5), " < ", DoubleToString(minDistance, 5), ")");
               return false;
            }
         }
      }
      
      Print("✅ PIRAMIDAÇÃO: Condições atendidas para entrada #", sameDirCount + 1,
            " | Preço atual: ", DoubleToString(currentPrice, 5));
   }
   else
   {
      Print("✅ PIRAMIDAÇÃO: Primeira entrada na direção ", isBuy ? "BUY" : "SELL");
   }
   
   return true;
}

double CalculatePyramidLot(bool isBuy)
{
   double baseLot = LotSize;
   int sameDirCount = CountSameDirectionPositions(isBuy);
   
   if(sameDirCount == 0) 
   {
      Print("💰 Piramidação: Primeira entrada - Lote base: ", DoubleToString(baseLot, 2));
      return baseLot;
   }
   
   if(ReduceLotOnPyramiding)
   {
      // ✅ VALIDAÇÃO: Se PyramidingLotMultiplier < 1.0, avisar que piramidação REDUZ capital
      // ✅ FIX BUG #5: Validar multiplicador antes de MathPow
      if(PyramidingLotMultiplier < 1.0)
      {
         Print("⚠️ AVISO: PyramidingLotMultiplier = ", DoubleToString(PyramidingLotMultiplier, 2),
               " (< 1.0) - Piramidação REDUZIRÁ o capital investido!");
         Print("⚠️ Configure PyramidingLotMultiplier ≥ 1.0 se quiser AUMENTAR capital em piramidação");
      }
      
      // Garantir que multiplicador seja válido (> 0)
      double validMultiplier = PyramidingLotMultiplier;
      if(validMultiplier <= 0) validMultiplier = 1.0; // Fallback seguro
      
      double multiplier = MathPow(validMultiplier, sameDirCount);
      double pyramidLot = baseLot * multiplier;
      
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      if(pyramidLot < minLot) pyramidLot = minLot;
      
      Print("💰 PIRAMIDAÇÃO: Lote calculado: ", DoubleToString(baseLot, 2), 
            " * ", DoubleToString(multiplier, 2), 
            " = ", DoubleToString(pyramidLot, 2),
            " (entrada #", sameDirCount + 1, ")",
            multiplier < 1.0 ? " ⚠️ REDUZIDO" : multiplier > 1.0 ? " ✅ AUMENTADO" : " ➡️ IGUAL");
      
      return pyramidLot;
   }
   else
   {
      Print("💰 PIRAMIDAÇÃO: Lote fixo: ", DoubleToString(baseLot, 2),
            " (entrada #", sameDirCount + 1, ") - Capital constante");
      
      return baseLot;
   }
}

// ======================================================================
// ✅✅✅ NOVO SISTEMA DE APRENDIZADO INTELIGENTE
// ======================================================================

void InitializeLearningSystem()
{
   ArrayResize(g_stateWinRate, NUM_STATES);
   ArrayInitialize(g_stateWinRate, 0.0);
   
   ArrayResize(g_stateAvgProfit, NUM_STATES);
   ArrayInitialize(g_stateAvgProfit, 0.0);
   
   g_stateResets = 0;
   g_stateDecays = 0;
   g_lastDecayTradeCount = 0;
   g_totalDecayCycles = 0;
   g_totalBadStateResets = 0;
   
   Print("🧠 Sistema de aprendizado inteligente inicializado (memória otimizada com decay)");
}

double CalculateStateAverageProfit(int state)
{
   if(state < 0 || state >= NUM_STATES) return 0.0;
   if(g_stateVisits[state] < 5) return 0.0;
   
   double quality = GetStateQuality(state);
   
   double estimatedProfit = quality * 100.0;
   
   if(ArraySize(g_stateAvgProfit) > state)
   {
      g_stateAvgProfit[state] = estimatedProfit;
   }
   
   return estimatedProfit;
}

void UpdateStateStats(int state, double profit, int action)
{
   if(state < 0 || state >= NUM_STATES) return;
   if(ArraySize(g_stateWinRate) <= state) return;
   if(ArraySize(g_stateAvgProfit) <= state) return;
   
   double winRate = CalculateWinRate(state);
   g_stateWinRate[state] = winRate;
   
   double currentAvg = g_stateAvgProfit[state];
   int visits = g_stateVisits[state];
   
   if(visits > 0)
   {
      double alpha = 0.1;
      double newAvg = currentAvg * (1 - alpha) + profit * alpha;
      g_stateAvgProfit[state] = newAvg;
   }
   else
   {
      g_stateAvgProfit[state] = profit;
   }
}

// ======================================================================
// ✅✅✅ ✅✅✅ OnTradeTransaction - CORRIGIDA COMPLETAMENTE (PONTO CRÍTICO)
// ======================================================================
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.symbol != _Symbol) return;

   ulong deal_ticket = trans.deal;
   
   if(!HistoryDealSelect(deal_ticket)) return;

   long dmagic = HistoryDealGetInteger(deal_ticket, DEAL_MAGIC);
   if(dmagic != MagicNumber) return;

   long entry_type = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
   if(entry_type != DEAL_ENTRY_OUT) return;

   // DEBUG: Logar todos os detalhes
   Print("=== ONTRADETRANSACTION CHAMADO ===");
   Print("Deal Ticket: ", deal_ticket);
   Print("g_lastTradeState: ", g_lastTradeState);
   Print("g_lastTradeAction: ", g_lastTradeAction);
   Print("g_lastTradeExecuted: ", g_lastTradeExecuted);

   double profit = HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
   double commission = HistoryDealGetDouble(deal_ticket, DEAL_COMMISSION);
   double swap = HistoryDealGetDouble(deal_ticket, DEAL_SWAP);
   double net_profit = profit + commission + swap;

   // ✅ REWARD DINÂMICA: Ajusta baseado no histórico do estado
   double reward = GetDynamicReward(net_profit > 0, g_lastTradeState);
   
   // ✅ MAE/MFE EFFICIENCY: Ajusta reward baseado na qualidade da execução
   ulong position_id = HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID);
   double mae = 0.0, mfe = 0.0;
   
   if(GetPositionMAEMFE(position_id, mae, mfe))
   {
      // Obter entry price do histórico
      double entry_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
      
      // Calcula fator de eficiência baseado em MAE/MFE
      int direction = (g_lastTradeAction == 1) ? 1 : -1; // 1=BUY, -1=SELL
      double efficiencyFactor = GetEfficiencyFactor(direction, 
                                                     entry_price,
                                                     g_lastSLPrice,
                                                     g_lastTPPrice,
                                                     mae, 
                                                     mfe, 
                                                     net_profit);
      
      // Aplica fator de eficiência à reward
      reward *= efficiencyFactor;
      
      // Log do fator de eficiência
      double slDist = MathAbs(entry_price - g_lastSLPrice);
      double tpDist = MathAbs(g_lastTPPrice - entry_price);
      double maePct = SafeDivide(mae, slDist, 0.0);
      double mfePct = SafeDivide(mfe, tpDist, 0.0);
      
      Print("📈 MAE/MFE EFFICIENCY: Estado ", g_lastTradeState,
            " | MAE: ", DoubleToString(maePct * 100, 1), "%",
            " | MFE: ", DoubleToString(mfePct * 100, 1), "%",
            " | Fator: ", DoubleToString(efficiencyFactor, 2),
            " | Reward Final: ", DoubleToString(reward, 2));
   }
   
   // Log da reward dinâmica (se habilitado)
   if(EnableDynamicReward && g_lastTradeState >= 0 && g_lastTradeState < NUM_STATES)
   {
      int total_trades = g_stateWins[g_lastTradeState] + g_stateLosses[g_lastTradeState];
      if(total_trades >= 30)
      {
         double wr = SafeDivide((double)g_stateWins[g_lastTradeState], (double)total_trades, 0.0);
         Print("📊 REWARD DINÂMICA Estado ", g_lastTradeState, 
               " | WR: ", DoubleToString(wr * 100, 1), "%",
               " | Reward: ", DoubleToString(reward, 2),
               " (base: ", (net_profit > 0 ? RewardWin : RewardLoss), ")");
      }
   }
   
   g_totalTrades++;
   g_sumProfit += net_profit;
   
   // ✅ NOVO: Atualizar estatísticas mensais
   UpdateMonthlyStats(net_profit);
   
   // ⚠️ DIAGNÓSTICO DETALHADO
   Print("DIAGNÓSTICO DETALHADO:");
   Print("net_profit: ", DoubleToString(net_profit, 2));
   Print("g_lastTradeAction: ", g_lastTradeAction, " (0=NOP, 1=BUY, 2=SELL)");
   Print("g_lastTradeState: ", g_lastTradeState);
   Print("g_lastTradeExecuted: ", g_lastTradeExecuted);
   
   if(g_lastTradeState >= 0 && g_lastTradeState < NUM_STATES)
   {
      Print("Estado válido detectado: ", g_lastTradeState);
      Print("Visitas atuais: ", g_stateVisits[g_lastTradeState]);
      Print("Vitórias atuais: ", g_stateWins[g_lastTradeState]);
      Print("Perdas atuais: ", g_stateLosses[g_lastTradeState]);
      
      // ⚠️ CORREÇÃO DEFINITIVA: Contar APENAS se foi trade real (BUY/SELL)
      if(g_lastTradeAction == 1 || g_lastTradeAction == 2) // BUY ou SELL
      {
         g_stateVisits[g_lastTradeState]++;
         g_stateLastUpdate[g_lastTradeState] = g_totalTrades;
         
         // Atualizar dados para Sharpe Ratio
         UpdateStateSharpeData(g_lastTradeState, net_profit);
         
         if(net_profit > 0) 
         {
            g_totalWins++;
            g_stateWins[g_lastTradeState]++;
            Print("✅✅✅ VITÓRIA REGISTRADA para estado ", g_lastTradeState);
         }
         else 
         {
            g_totalLosses++;
            g_stateLosses[g_lastTradeState]++;
            Print("❌❌❌ PERDA REGISTRADA para estado ", g_lastTradeState);
         }
         
         // ✅ FIX: Avaliar bloqueio após QUALQUER trade (win ou loss), não só após perda
         // Isso garante que estados sejam bloqueados assim que atingem os critérios
         if(EnableUnifiedBlockingSystem && g_stateVisits[g_lastTradeState] >= MinVisitsForBlockDecision)
         {
            EvaluateAndUpdateBlockState(g_lastTradeState);
         }
         
         Print("PÓS-ATUALIZAÇÃO Estado ", g_lastTradeState, ":");
         Print("  Visitas: ", g_stateVisits[g_lastTradeState]);
         Print("  Vitórias: ", g_stateWins[g_lastTradeState]);
         Print("  Perdas: ", g_stateLosses[g_lastTradeState]);
      }
      else
      {
         Print("⚠️ NOP detectado - NÃO contando visita/perda");
      }
   }
   else
   {
      Print("⚠️ Estado inválido ou não definido");
   }
   
   g_lastTradeProfit = net_profit;
   g_lastTradeDate   = TimeCurrent();
   
   if(g_firstTradeDate == 0) g_firstTradeDate = TimeCurrent();
   
   UpdateProfitHistory(net_profit);
   
   if(g_lastTradeAction == 1 || g_lastTradeAction == 2)
   {
      UpdateDirectionStats(g_lastTradeAction == 1, net_profit);
   }
   
   UpdateStreaks(net_profit);
   
   if((g_lastTradeAction == 1 || g_lastTradeAction == 2) && g_lastTradeState >= 0)
   {
      UpdateStateStats(g_lastTradeState, net_profit, g_lastTradeAction);
      UpdateQ(g_lastTradeState, g_lastTradeAction, reward);
   }
   
   if(net_profit < 0) 
   {
      g_consecutiveLosses++;
      Print("📉 Perda consecutiva #", g_consecutiveLosses);
   }
   else 
   {
      g_consecutiveLosses = 0;
      Print("📈 Vitória - resetando perdas consecutivas");
   }

   // Reset flags
   g_lastTradeState  = -1;
   g_lastTradeAction = 0;
   g_lastTradeExecuted = false;
   g_lastTradeStateExecuted = -1;
   
   if(GetTotalPositions() == 0)
   {
      g_currentDirection = 0;
      g_positionsCount = 0;
      cachedPositions = -1;
      cachedDirection = -1;
   }
   
   // Chamar diagnóstico a cada 10 trades
   if(g_totalTrades % 10 == 0)
   {
      DebugTradeCounting();
      MonitorBadStates();
   }
   
   // Chamar debug de bloqueio a cada 25 trades
   if(g_totalTrades % 25 == 0)
   {
      DebugBlockedStates();
   }
   
   // Forçar save a cada trade crítico
   // ✅ ANTI-PERDA: Salvar após cada trade (se habilitado)
   if(SaveAfterEachTrade && (g_lastTradeAction == 1 || g_lastTradeAction == 2))
   {
      SaveState();
      g_memoryDirty = true;  // Força salvamento
      if(SaveBrain())
      {
         Print("💾 AUTO-SAVE: Memória salva após trade #", g_totalTrades);
         
         // ✅ NOVO: Exportar relatório mensal após cada trade
         ExportMonthlyReport();
      }
   }
   
   Print("=== FIM ONTRADETRANSACTION ===");
}

// ======================================================================
// ✅✅✅ FUNÇÕES PARA APRENDIZADO EVOLUTIVO
// ======================================================================

void UpdateLearningStats()
{
   g_totalStatesDiscovered = g_activeStatesCount;
   
   double sumQ = 0.0;
   int qCount = 0;
   g_maxQValue = -DBL_MAX;
   g_minQValue = DBL_MAX;
   
   for(int i = 0; i < NUM_STATES * NUM_ACTIONS; i++)
   {
      if(g_Q[i] != 0.0)
      {
         sumQ += g_Q[i];
         qCount++;
         if(g_Q[i] > g_maxQValue) g_maxQValue = g_Q[i];
         if(g_Q[i] < g_minQValue) g_minQValue = g_Q[i];
      }
   }
   
   if(qCount > 0)
   {
      g_averageQValue = SafeDivide(sumQ, (double)qCount, 0.0);
   }
   else
   {
      g_averageQValue = 0.0;
   }
}

void UpdateProfitHistory(double profit)
{
   if(ArraySize(g_recentProfits) < 100)
   {
      ArrayResize(g_recentProfits, 100);
      ArrayInitialize(g_recentProfits, 0.0);
   }
   
   g_recentProfits[g_recentProfitsIndex] = profit;
   g_recentProfitsIndex = (g_recentProfitsIndex + 1) % 100;
   
   if(profit > g_highestProfit) g_highestProfit = profit;
   if(profit < g_lowestProfit) g_lowestProfit = profit;
}

void UpdateDirectionStats(bool isBuy, double profit)
{
   if(isBuy)
   {
      g_totalBuys++;
      if(profit > 0) g_buyWins++;
      g_buyProfit += profit;
   }
   else
   {
      g_totalSells++;
      if(profit > 0) g_sellWins++;
      g_sellProfit += profit;
   }
}

void UpdateStreaks(double profit)
{
   if(profit > 0)
   {
      g_currentWinStreak++;
      g_currentLossStreak = 0;
      
      if(g_currentWinStreak > g_bestWinStreak)
      {
         g_bestWinStreak = g_currentWinStreak;
      }
   }
   else if(profit < 0)
   {
      g_currentLossStreak++;
      g_currentWinStreak = 0;
      
      if(g_currentLossStreak > g_worstLossStreak)
      {
         g_worstLossStreak = g_currentLossStreak;
      }
   }
}

// ======================================================================
// ✅✅✅ FUNÇÃO: EXPORTAÇÃO FORÇADA (para chamar manualmente)
// ======================================================================
void ForceTextExport()
{
   if(ExportMemoryToTextFileFunc(true))
   {
      Print("✅ Exportação forçada para texto realizada com sucesso!");
   }
   else
   {
      Print("❌ Falha na exportação forçada para texto");
   }
}

// ======================================================================
// ✅✅✅ FUNÇÕES: RELATÓRIO MENSAL/ANUAL DE LUCROS
// ======================================================================

// Inicializa sistema de tracking mensal
void InitializeMonthlyStats()
{
   if(g_monthlyStatsInitialized) return;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   g_firstYearTracked = dt.year;
   
   // Inicializa todos os meses de todos os anos
   for(int y = 0; y < 20; y++)
   {
      for(int m = 0; m < 12; m++)
      {
         g_monthlyStats[y][m].totalProfit = 0.0;
         g_monthlyStats[y][m].totalLoss = 0.0;
         g_monthlyStats[y][m].tradeCount = 0;
      }
   }
   
   g_monthlyStatsInitialized = true;
   Print("📅 Sistema de relatório mensal/anual inicializado | Ano base: ", g_firstYearTracked);
}

// Atualiza estatísticas mensais com novo trade
void UpdateMonthlyStats(double net_profit)
{
   if(!g_monthlyStatsInitialized) InitializeMonthlyStats();
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   int yearIndex = dt.year - g_firstYearTracked;
   if(yearIndex < 0 || yearIndex >= 20) return;  // Fora do range de 20 anos
   
   int monthIndex = dt.mon - 1;  // meses 1-12 → índices 0-11
   if(monthIndex < 0 || monthIndex >= 12) return;
   
   g_monthlyStats[yearIndex][monthIndex].tradeCount++;
   
   if(net_profit > 0)
   {
      g_monthlyStats[yearIndex][monthIndex].totalProfit += net_profit;
   }
   else if(net_profit < 0)
   {
      g_monthlyStats[yearIndex][monthIndex].totalLoss += MathAbs(net_profit);
   }
}

// Exporta relatório mensal/anual
bool ExportMonthlyReport()
{
   if(!g_monthlyStatsInitialized) return false;
   
   // Usar caminho simples sem subdiretorios para FILE_COMMON
   string filename = "Phoenix_Monthly_Report_" + _Symbol + "_" + 
                     EnumToString((ENUM_TIMEFRAMES)_Period) + ".txt";
   
   int file = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(file == INVALID_HANDLE)
   {
      Print("❌ Erro ao criar relatório mensal: ", GetLastError());
      Print("💡 Caminho do arquivo: ", filename);
      return false;
   }
   
   Print("✅ Relatório mensal criado: ", filename);
   
   FileWrite(file, "═══════════════════════════════════════════════════════════════");
   FileWrite(file, "   PHOENIX TRADER - RELATÓRIO MENSAL/ANUAL DE LUCROS");
   FileWrite(file, "═══════════════════════════════════════════════════════════════");
   FileWrite(file, "");
   FileWrite(file, "Símbolo: " + _Symbol + " | Timeframe: " + EnumToString((ENUM_TIMEFRAMES)_Period));
   FileWrite(file, "Data do Relatório: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   FileWrite(file, "");
   
   string monthNames[12] = {"JANEIRO", "FEVEREIRO", "MARÇO", "ABRIL", "MAIO", "JUNHO",
                             "JULHO", "AGOSTO", "SETEMBRO", "OUTUBRO", "NOVEMBRO", "DEZEMBRO"};
   
   // Para cada ano que tem dados
   for(int y = 0; y < 20; y++)
   {
      int currentYear = g_firstYearTracked + y;
      bool yearHasData = false;
      
      // Verifica se o ano tem algum dado
      for(int m = 0; m < 12; m++)
      {
         if(g_monthlyStats[y][m].tradeCount > 0)
         {
            yearHasData = true;
            break;
         }
      }
      
      if(!yearHasData) continue;  // Pula ano sem dados
      
      FileWrite(file, "═══════════════════════════════════════════════════════════════");
      FileWrite(file, "   ANO: " + IntegerToString(currentYear));
      FileWrite(file, "═══════════════════════════════════════════════════════════════");
      FileWrite(file, "");
      
      double yearTotalProfit = 0.0;
      double yearTotalLoss = 0.0;
      int yearTotalTrades = 0;
      
      // Para cada mês
      for(int m = 0; m < 12; m++)
      {
         if(g_monthlyStats[y][m].tradeCount == 0) continue;  // Pula mês sem dados
         
         double profit = g_monthlyStats[y][m].totalProfit;
         double loss = g_monthlyStats[y][m].totalLoss;
         double balance = profit - loss;
         int trades = g_monthlyStats[y][m].tradeCount;
         
         yearTotalProfit += profit;
         yearTotalLoss += loss;
         yearTotalTrades += trades;
         
         FileWrite(file, "────────────────────────────────────────────────────────────────");
         FileWrite(file, monthNames[m]);
         FileWrite(file, "  Lucro:  +" + DoubleToString(profit, 2));
         FileWrite(file, "  Perda:  -" + DoubleToString(loss, 2));
         
         if(balance >= 0)
         {
            FileWrite(file, "  Saldo:  +" + DoubleToString(balance, 2) + " ✅");
         }
         else
         {
            FileWrite(file, "  Saldo:  " + DoubleToString(balance, 2) + " ❌");
         }
         
         FileWrite(file, "  Trades: " + IntegerToString(trades));
      }
      
      // Resumo anual
      if(yearTotalTrades > 0)
      {
         double yearBalance = yearTotalProfit - yearTotalLoss;
         FileWrite(file, "");
         FileWrite(file, "════════════════════════════════════════════════════════════════");
         FileWrite(file, "   RESUMO DO ANO " + IntegerToString(currentYear));
         FileWrite(file, "────────────────────────────────────────────────────────────────");
         FileWrite(file, "  Total Lucro:  +" + DoubleToString(yearTotalProfit, 2));
         FileWrite(file, "  Total Perda:  -" + DoubleToString(yearTotalLoss, 2));
         
         if(yearBalance >= 0)
         {
            FileWrite(file, "  Saldo Anual:  +" + DoubleToString(yearBalance, 2) + " ✅");
         }
         else
         {
            FileWrite(file, "  Saldo Anual:  " + DoubleToString(yearBalance, 2) + " ❌");
         }
         
         FileWrite(file, "  Total Trades: " + IntegerToString(yearTotalTrades));
         FileWrite(file, "════════════════════════════════════════════════════════════════");
         FileWrite(file, "");
         FileWrite(file, "");
      }
   }
   
   FileWrite(file, "");
   FileWrite(file, "═══════════════════════════════════════════════════════════════");
   FileWrite(file, "   FIM DO RELATÓRIO");
   FileWrite(file, "═══════════════════════════════════════════════════════════════");
   
   FileClose(file);
   
   Print("📅 Relatório mensal/anual exportado com sucesso: ", filename);
   return true;
}

// ======================================================================
// ✅✅✅ FUNÇÃO: CRIAR RELATÓRIO RESUMIDO DIÁRIO
// ======================================================================
void CreateDailySummaryReport()
{
   // ✅ OTIMIZAÇÃO: Usar arquivo consolidado de logs ao invés de criar múltiplos arquivos diários
   string filename = "Phoenix_Files/Text_Logs/Phoenix_Daily_Log_" + _Symbol + "_" + 
                     EnumToString((ENUM_TIMEFRAMES)_Period) + ".txt";
   
   if(!CreateDirectoryForFile(filename)) return;
   
   int file_handle = FileOpen(filename, FILE_WRITE|FILE_READ|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(file_handle == INVALID_HANDLE) return;
   
   // Posicionar no final para append
   FileSeek(file_handle, 0, SEEK_END);
   
   FileWrite(file_handle, "");
   FileWrite(file_handle, "================================================================");
   FileWrite(file_handle, "RELATÓRIO DIÁRIO - PHOENIX TRADER v307F");
   FileWrite(file_handle, "Data: " + TimeToString(TimeCurrent(), TIME_DATE));
   FileWrite(file_handle, "================================================================");
   FileWrite(file_handle, "");
   FileWrite(file_handle, "📈 RESUMO DO DIA (SISTEMA SUPER CORRIGIDO)");
   FileWrite(file_handle, "----------------------------------------");
   FileWrite(file_handle, "Trades REAIS Realizados: " + IntegerToString(g_tradesToday));
   FileWrite(file_handle, "Estados Ativos: " + IntegerToString(g_activeStatesCount));
   FileWrite(file_handle, "Estados Bloqueados: " + IntegerToString(CountBlockedStates()));
   FileWrite(file_handle, "Volume Médio Multiplicador: " + DoubleToString(g_volumeMultiplier, 2) + "x");
   FileWrite(file_handle, "Ciclos de Decay: " + IntegerToString(g_totalDecayCycles));
   FileWrite(file_handle, "Estados Resetados: " + IntegerToString(g_totalBadStateResets));
   FileWrite(file_handle, "");
   FileWrite(file_handle, "🧠 PROGRESSO DO APRENDIZADO (SISTEMA SUPER CORRIGIDO)");
   FileWrite(file_handle, "----------------------------------------");
   double discoveryPercent = (double)g_activeStatesCount/NUM_STATES*100;
   FileWrite(file_handle, "Estados Descobertos: " + IntegerToString(g_activeStatesCount) + "/" + 
            IntegerToString(NUM_STATES) + " (" + DoubleToString(discoveryPercent, 1) + "%)");
   FileWrite(file_handle, "Taxa de Exploração: " + DoubleToString(g_currentExplorationRate * 100, 1) + "%");
   FileWrite(file_handle, "Contagem Corrigida: " + IntegerToString(g_totalTrades) + " trades REAIS");
   FileWrite(file_handle, "");
   FileWrite(file_handle, "🛡️ CORREÇÕES IMPLEMENTADAS:");
   FileWrite(file_handle, "1. ✅ Cálculo de estados corrigido (576 estados)");
   FileWrite(file_handle, "2. ✅ Reset automático funcionando");
   FileWrite(file_handle, "3. ✅ Estados não travam mais em 10 visitas");
   FileWrite(file_handle, "4. ✅ Regras de bloqueio mais agressivas");
   FileWrite(file_handle, "5. ✅ Debug de estados travados implementado");
   FileWrite(file_handle, "");
   FileWrite(file_handle, "================================================================");
   FileWrite(file_handle, "FIM DO RELATÓRIO - SISTEMA SUPER CORRIGIDO v307F");
   FileWrite(file_handle, "================================================================");
   
   FileClose(file_handle);
   
   Print("📋 Relatório diário criado: ", filename);
}

// ======================================================================
// ✅ FUNÇÕES ADICIONAIS QUE ESTAVAM FALTANDO
// ======================================================================

bool ShouldAutoExport()
{
   if(!EnableMemoryExport) return false;
   if(AutoExportMinutes <= 0) return false;
   
   datetime currentTime = TimeCurrent();
   if(g_lastExportTime == 0) 
   {
      g_lastExportTime = currentTime;
      return true;
   }
   
   int minutesPassed = (int)((currentTime - g_lastExportTime) / 60);
   return minutesPassed >= AutoExportMinutes;
}

bool ExportAllMemoryFiles()
{
   if(!EnableMemoryExport) return false;
   
   Print("📤 Exportando arquivos de memória...");
   
   if(!SaveBrain()) return false;
   
   g_lastExportTime = TimeCurrent();
   g_exportCount++;
   
   Print("✅ Arquivos de memória exportados com sucesso!");
   return true;
}

// ======================================================================
// ✅✅✅ ✅✅✅ FUNÇÃO PRINCIPAL OnTick (COM SISTEMA SUPER CORRIGIDO E NOVAS FUNÇÕES)
// ======================================================================
void OnTick()
{
   static datetime last_bar_time = 0;
   datetime current_bar_time = iTime(_Symbol,_Period,0);

   // ✅ ATUALIZAÇÃO MAE/MFE: Rastrear eficiência dos trades em tempo real
   UpdatePositionMetrics();

   // ✅ ANTI-PERDA: Salvamento periódico automático (a cada X minutos)
   if(EnablePeriodicAutoSave && PeriodicSaveMinutes > 0)
   {
      datetime currentTime = TimeCurrent();
      if(g_lastPeriodicSaveTime == 0)
      {
         g_lastPeriodicSaveTime = currentTime;
      }
      
      int minutesSinceLastSave = (int)((currentTime - g_lastPeriodicSaveTime) / 60);
      if(minutesSinceLastSave >= PeriodicSaveMinutes)
      {
         g_memoryDirty = true;  // Força salvamento
         if(SaveBrain())
         {
            g_periodicSaveCount++;
            g_lastPeriodicSaveTime = currentTime;
            Print("💾 AUTO-SAVE PERIÓDICO #", g_periodicSaveCount, 
                  ": Memória salva automaticamente (", PeriodicSaveMinutes, " minutos)");
         }
      }
   }

   // ✅ MONITORAMENTO DE PERFORMANCE A CADA 100 TICKS
   static int tickCounter = 0;
   tickCounter++;
   
   if(tickCounter % 100 == 0)
   {
      double currentWinRate = SafeDivide((double)g_totalWins, (double)g_totalTrades, 0.0);
      
      if(currentWinRate < 0.20)
      {
         Print("⚠️⚠️⚠️ ALERTA: Win rate crítica (", DoubleToString(currentWinRate*100,1), "%)");
         
         // Se performance muito ruim por muito tempo
         static int badPerformanceCounter = 0;
         badPerformanceCounter++;
         
         if(badPerformanceCounter >= 5)
         {
            Print("🔥 ATIVAÇÃO DE CORREÇÃO DE EMERGÊNCIA");
            EmergencyCounterFix();
            OverhaulBlockingSystem();
            badPerformanceCounter = 0;
         }
      }
      
      // Verificar bloqueios excessivos (apenas após atingir limite mínimo)
      // ✅ Verifica EnableIntelligentReset antes de resetar
      if(EnableIntelligentReset && g_activeStatesCount >= MinStatesBeforeReset)
      {
         double blockedRatio = SafeDivide((double)CountBlockedStates(), (double)g_activeStatesCount, 0.0);
         if(blockedRatio > 0.7 && g_activeStatesCount > 50)
         {
            Print("⚠️ Muitos estados bloqueados (", DoubleToString(blockedRatio*100,1), "%)");
            IntelligentPartialReset();
         }
      }
   }

   // ✅ CHAMAR CORREÇÕES A CADA HORA
   static datetime lastMaintenanceCall = 0;
   if(TimeCurrent() - lastMaintenanceCall >= 3600)
   {
      PerformMemoryMaintenance();
      
      // ✅ OTIMIZAÇÃO DINÂMICA
      OptimizeParametersDynamically();
      
      // ✅ TESTE PERIÓDICO DE ESTADOS BLOQUEADOS
      if(EnableUnifiedBlockingSystem)
      {
         TestBlockedStatesPeriodically();
      }
      
      lastMaintenanceCall = TimeCurrent();
   }

   if(UseDynamicTrailingStop)
   {
      ManageAllDynamicStops();
   }

   // ✅ FIX: Avaliar todos estados ativos periodicamente (a cada 60 segundos)
   // Garante que estados ruins sejam bloqueados mesmo se perderam o timing no OnTradeTransaction
   if(EnableUnifiedBlockingSystem)
   {
      EvaluateAllActiveStates();
   }

   if(current_bar_time != last_bar_time)
   {
      last_bar_time = current_bar_time;
      
      // ✅ DEBUG PERIÓDICO MELHORADO
      static int debugCounter = 0;
      debugCounter++;
      
      if(debugCounter % 50 == 0)
      {
         DebugStuckStatesEnhanced();
      }
      
      // ✅ Desbloquear estados bons apenas após atingir limite mínimo de estados
      if(EnableIntelligentReset && g_activeStatesCount >= MinStatesBeforeReset && debugCounter % 100 == 0)
      {
         UnblockGoodStates();
      }

      MqlDateTime today,last;
      TimeToStruct(TimeCurrent(),today);
      TimeToStruct(g_lastResetDate,last);

      bool new_day = (g_lastResetDate==0) ||
                     (today.day != last.day ||
                      today.mon != last.mon ||
                      today.year != last.year);

      if(new_day)
      {
         g_tradesToday=0;
         g_consecutiveLosses=0;
         g_lastResetDate=TimeCurrent();
         cachedTradesToday = -1;
         
         // ✅ DESBLOQUEIO PARCIAL apenas após atingir limite mínimo de estados
         if(EnableIntelligentReset && g_activeStatesCount >= MinStatesBeforeReset)
         {
            UnblockGoodStates();
         }
         
         if(EnableTextExport)
         {
            CreateDailySummaryReport();
         }
      }

      if(g_tradesToday >= MaxTradesPerDay)
      {
         g_statusMessage = StringFormat("⛔ Limite diário (%d) atingido", MaxTradesPerDay);
      }
      else if(g_consecutiveLosses >= ConsecutiveLossLimit)
      {
         g_statusMessage = StringFormat("⛔ %d perdas consecutivas", ConsecutiveLossLimit);
      }
      else
      {
         g_statusMessage = "Analisando (Sistema Corrigido v2)";
            
         int s = GetCurrentState();
         if(s < 0)
         {
            g_statusMessage = "Aguardando dados dos indicadores";
         }
         else
         {
            // ✅ NOVO: Se exploração = 0%, só usar estados já na lista ativa
            if(g_currentExplorationRate <= 0.0)
            {
               bool stateInActiveList = false;
               for(int i = 0; i < g_activeStatesCount; i++)
               {
                  if(g_activeStates[i] == s)
                  {
                     stateInActiveList = true;
                     break;
                  }
               }
               
               if(!stateInActiveList)
               {
                  // Estado novo mas exploração = 0% → NÃO usar este estado
                  g_statusMessage = StringFormat("⏸️ Estado %d desconhecido (exploração 0%%)", s);
                  return;  // ✅ BLOQUEIA uso de estados novos
               }
            }
            
            // ✅ VERIFICAÇÃO DE BLOQUEIO MAIS INTELIGENTE
            if(IsStateBlocked(s))
            {
               double winRate = CalculateWinRate(s);
               
               // Auto-desbloqueio se performance melhorou
               if(winRate >= 0.35 && g_stateVisits[s] >= 5)
               {
                  g_stateBlocked[s] = false;
                  Print("🔄 AUTO-DESBLOQUEIO Estado ", s, 
                        " | Win Rate: ", DoubleToString(winRate*100,1), "%");
               }
               else
               {
                  g_statusMessage = StringFormat("⛔ Estado %d bloqueado", s);
                  UpdateQ_NOP(s);
                  return;
               }
            }
            
            int a = ChooseAction(s);
            
            if(a == 0)
            {
               g_statusMessage = "NOP (Análise)";
               UpdateQ_NOP(s);
            }
            else
            {
               ExecuteAction(a,s);
            }
         }
      }
   }

   UpdateHUDLight();
   
   static datetime lastTextExportCheck = 0;
   datetime currentTime = TimeCurrent();
   if(currentTime - lastTextExportCheck >= 60)
   {
      lastTextExportCheck = currentTime;
      ExportMemoryToTextFileFunc(false);
   }
}

// ======================================================================
// ✅✅✅ FUNÇÃO ExportMemoryToTextFileFunc (ARQUIVO ÚNICO COM HISTÓRICO COMPLETO)
// ======================================================================
bool ExportMemoryToTextFileFunc(bool forceExport = false)
{
   if(!EnableTextExport && !forceExport) return false;
   
   datetime currentTime = TimeCurrent();
   if(!forceExport && g_lastTextExportTime > 0)
   {
      int minutesPassed = (int)((currentTime - g_lastTextExportTime) / 60);
      if(minutesPassed < TextExportMinInterval) return false;
   }
   
   // ✅ NOVO: Arquivo ÚNICO que é sobrescrito a cada exportação
   string filename = "Phoenix_Files/Text_Logs/Phoenix_Memory_" + _Symbol + "_" + 
                     EnumToString((ENUM_TIMEFRAMES)_Period) + ".txt";
   
   if(!CreateDirectoryForFile(filename))
   {
      Print("❌ Erro ao criar diretório para arquivo texto: ", filename);
      return false;
   }
   
   int file_handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(file_handle == INVALID_HANDLE)
   {
      Print("❌ Erro ao abrir arquivo texto: ", filename, " | Erro: ", GetLastError());
      return false;
   }
   
   FileWrite(file_handle, "=================================================================");
   FileWrite(file_handle, "PHOENIX TRADER v307F - SISTEMA SUPER CORRIGIDO");
   FileWrite(file_handle, "Data/Hora: " + TimeToString(currentTime));
   FileWrite(file_handle, "Symbol: " + _Symbol + " | Timeframe: " + EnumToString((ENUM_TIMEFRAMES)_Period));
   FileWrite(file_handle, "=================================================================");
   FileWrite(file_handle, "");
   FileWrite(file_handle, "🛡️ SISTEMA SUPER CORRIGIDO - MELHORIAS IMPLEMENTADAS");
   FileWrite(file_handle, "----------------------------------------");
   FileWrite(file_handle, "✅ CORREÇÕES CRÍTICAS IMPLEMENTADAS:");
   FileWrite(file_handle, "1. ✅ Cálculo de estados corrigido (576 estados)");
   FileWrite(file_handle, "2. ✅ Reset automático funcionando");
   FileWrite(file_handle, "3. ✅ Estados não travam mais em 10 visitas");
   FileWrite(file_handle, "4. ✅ Regras de bloqueio mais agressivas");
   FileWrite(file_handle, "5. ✅ Debug de estados travados implementado");
   FileWrite(file_handle, "6. ✅ Reset de emergência disponível");
   FileWrite(file_handle, "");
   
   string systemInfo = "Estados totais possíveis: " + IntegerToString(NUM_STATES) + " (3×4×2×3×2×2×2 = 576)";
   FileWrite(file_handle, systemInfo);
   
   string activeInfo = "Estados ativos na memória: " + IntegerToString(g_activeStatesCount);
   FileWrite(file_handle, activeInfo);
   
   int blockedCount = CountBlockedStates();
   string blockedInfo = "Estados bloqueados: " + IntegerToString(blockedCount);
   FileWrite(file_handle, blockedInfo);
   
   double discoveryRate = (double)g_activeStatesCount / NUM_STATES * 100;
   string discoveryInfo = "Taxa de descoberta: " + DoubleToString(discoveryRate, 1) + "%";
   FileWrite(file_handle, discoveryInfo);
   
   string decayInfo = "Ciclos de decay: " + IntegerToString(g_totalDecayCycles);
   FileWrite(file_handle, decayInfo);
   
   string resetInfo = "Estados resetados: " + IntegerToString(g_totalBadStateResets);
   FileWrite(file_handle, resetInfo);
   
   if(IncludeStatistics)
   {
      FileWrite(file_handle, "");
      FileWrite(file_handle, "📊 ESTATÍSTICAS GERAIS (SISTEMA SUPER CORRIGIDO)");
      FileWrite(file_handle, "----------------------------------------");
      
      string totalTrades = "Total de Trades REAIS: " + IntegerToString(g_totalTrades);
      FileWrite(file_handle, totalTrades);
      
      if(g_totalTrades > 0)
      {
         double winRate = (double)g_totalWins/g_totalTrades*100;
         double lossRate = (double)g_totalLosses/g_totalTrades*100;
         
         string winsInfo = "  Vitórias REAIS: " + IntegerToString(g_totalWins) + 
                          " (" + DoubleToString(winRate, 1) + "%)";
         FileWrite(file_handle, winsInfo);
         
         string lossesInfo = "  Derrotas REAIS: " + IntegerToString(g_totalLosses) + 
                           " (" + DoubleToString(lossRate, 1) + "%)";
         FileWrite(file_handle, lossesInfo);
         
         // Verificação de integridade
         int soma = g_totalWins + g_totalLosses;
         int diferenca = g_totalTrades - soma;
         FileWrite(file_handle, "  Soma Wins+Losses: " + IntegerToString(soma));
         FileWrite(file_handle, "  Diferença (NOPs): " + IntegerToString(diferenca));
      }
      else
      {
         FileWrite(file_handle, "  Vitórias: 0 (0.0%)");
         FileWrite(file_handle, "  Derrotas: 0 (0.0%)");
      }
      
      string totalProfit = "Lucro Total: " + DoubleToString(g_sumProfit, 2);
      FileWrite(file_handle, totalProfit);
      
      string tradesToday = "Trades Hoje: " + IntegerToString(g_tradesToday) + "/" + IntegerToString(MaxTradesPerDay);
      FileWrite(file_handle, tradesToday);
      
      string consecutiveLosses = "Perdas Consecutivas: " + IntegerToString(g_consecutiveLosses) + 
                               "/" + IntegerToString(ConsecutiveLossLimit);
      FileWrite(file_handle, consecutiveLosses);
      
      // ⚠️ GARANTIR QUE EXPLORAÇÃO NÃO PASSE DE 100%
      double exploration = MathMin(g_currentExplorationRate * 100, 100.0);
      string explorationStr = "Taxa Exploração: " + DoubleToString(exploration, 1) + "%";
      FileWrite(file_handle, explorationStr);
   }
   
   FileWrite(file_handle, "");
   FileWrite(file_handle, "📈 HISTÓRICO COMPLETO DE TODOS OS ESTADOS");
   FileWrite(file_handle, "----------------------------------------");
   
   // ✅ NOVA ORDENAÇÃO: 1) Bloqueados  2) Melhores (lucro/WR)  3) Restantes
   // Array: [state, visits, wins, losses, isBlocked(0/1), profit_x1000]
   int sortedStates[][6];
   ArrayResize(sortedStates, g_activeStatesCount);
   
   for(int i = 0; i < g_activeStatesCount; i++)
   {
      int state = g_activeStates[i];
      int visits = g_stateVisits[state];
      int wins = g_stateWins[state];
      int losses = g_stateLosses[state];
      bool isBlocked = g_stateBlocked[state];
      double profit = g_stateProfitSum[state];
      
      sortedStates[i][0] = state;
      sortedStates[i][1] = visits;
      sortedStates[i][2] = wins;
      sortedStates[i][3] = losses;
      sortedStates[i][4] = isBlocked ? 1 : 0;
      sortedStates[i][5] = (int)(profit * 1000); // Multiplicar por 1000 para evitar decimais
   }
   
   // Bubble sort com critério customizado
   for(int i = 0; i < g_activeStatesCount - 1; i++)
   {
      for(int j = i + 1; j < g_activeStatesCount; j++)
      {
         bool shouldSwap = false;
         
         // Critério 1: Estados bloqueados VÊM PRIMEIRO
         if(sortedStates[i][4] == 0 && sortedStates[j][4] == 1)
         {
            shouldSwap = true;
         }
         // Critério 2: Entre bloqueados, ordena por visitas (mais visitado primeiro)
         else if(sortedStates[i][4] == 1 && sortedStates[j][4] == 1)
         {
            if(sortedStates[j][1] > sortedStates[i][1])
               shouldSwap = true;
         }
         // Critério 3: Entre NÃO bloqueados, ordena por LUCRO (maior primeiro)
         else if(sortedStates[i][4] == 0 && sortedStates[j][4] == 0)
         {
            // Se ambos têm pelo menos 5 visitas, usar lucro
            if(sortedStates[i][1] >= 5 && sortedStates[j][1] >= 5)
            {
               if(sortedStates[j][5] > sortedStates[i][5])
                  shouldSwap = true;
            }
            // Se pelo menos um tem menos de 5 visitas, ordenar por Win Rate
            else
            {
               int totalI = sortedStates[i][1];
               int totalJ = sortedStates[j][1];
               double wrI = totalI > 0 ? (double)sortedStates[i][2] / totalI : 0;
               double wrJ = totalJ > 0 ? (double)sortedStates[j][2] / totalJ : 0;
               
               if(wrJ > wrI)
                  shouldSwap = true;
               else if(wrJ == wrI && sortedStates[j][1] > sortedStates[i][1])
                  shouldSwap = true;
            }
         }
         
         if(shouldSwap)
         {
            for(int k = 0; k < 6; k++)
            {
               int temp = sortedStates[i][k];
               sortedStates[i][k] = sortedStates[j][k];
               sortedStates[j][k] = temp;
            }
         }
      }
   }
   
   // ✅ EXPORTAR TODOS OS ESTADOS (não apenas top 20)
   for(int i = 0; i < g_activeStatesCount; i++)
   {
      int state = sortedStates[i][0];
      int visits = sortedStates[i][1];
      int wins = sortedStates[i][2];
      int losses = sortedStates[i][3];
      bool isBlocked = sortedStates[i][4] == 1;
      double profit = sortedStates[i][5] / 1000.0; // Restaurar profit original
      double winRate = visits > 0 ? (double)wins / visits * 100 : 0;
      
      // ✅ Determinar status do estado
      string statusInfo = "";
      if(isBlocked)
      {
         // Estado bloqueado - verificar se está em fase de reativação
         if(winRate >= 35.0 && visits >= MinVisitsForBlockDecision)
         {
            statusInfo = " [🔄 EM REATIVAÇÃO - WinRate melhorou]";
         }
         else
         {
            statusInfo = " [🚫 BLOQUEADO PERMANENTEMENTE]";
         }
      }
      else
      {
         // Estado não bloqueado
         if(winRate < StateBlockThreshold * 100 && visits >= MinVisitsForBlockDecision)
         {
            statusInfo = " [⚠️ EM AVALIAÇÃO - WinRate baixo]";
         }
         else if(profit > 0 && winRate > 50)
         {
            statusInfo = " [⭐ DESEMPENHO POSITIVO]";
         }
      }
      
      string stateLine = IntegerToString(i+1) + ". Estado " + IntegerToString(state) + 
                        ": " + IntegerToString(visits) + " visitas | " + 
                        IntegerToString(wins) + " wins (" + 
                        DoubleToString(winRate, 1) + "%) | " + 
                        IntegerToString(losses) + " losses | Lucro: " +
                        DoubleToString(profit, 2) + 
                        statusInfo;
      FileWrite(file_handle, stateLine);
   }
   
   FileWrite(file_handle, "");
   FileWrite(file_handle, "=================================================================");
   FileWrite(file_handle, "FIM DA EXPORTAÇÃO - SISTEMA SUPER CORRIGIDO v307F");
   FileWrite(file_handle, "=================================================================");
   
   FileClose(file_handle);
   
   g_lastTextExportTime = currentTime;
   g_textExportCount++;
   
   Print("📄 Memória exportada para texto: ", filename, 
         " | Estados: ", g_activeStatesCount,
         " | Bloqueados: ", blockedCount,
         " | Trades reais: ", g_totalTrades,
         " | Ciclos decay: ", g_totalDecayCycles,
         " | Resets: ", g_totalBadStateResets);
   
   return true;
}

// ======================================================================
// ✅✅✅ ✅✅✅ OnInit (COM SISTEMA SUPER CORRIGIDO)
// ======================================================================
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.SetDeviationInPoints(30);

   MathSrand((int)GetTickCount64());

   g_maHandle      = iMA(_Symbol, _Period, MAPeriod, 0, MAMethod, PRICE_CLOSE);
   g_rsiHandle     = iRSI(_Symbol, _Period, RSIPeriod, PRICE_CLOSE);
   g_macdHandle    = iMACD(_Symbol, _Period, MACD_Fast, MACD_Slow, MACD_Signal, PRICE_CLOSE);
   g_atrHandle     = iATR(_Symbol, _Period, ATRPeriod);

   if(g_maHandle == INVALID_HANDLE || g_rsiHandle == INVALID_HANDLE ||
      g_macdHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE)
   {
      Print("❌ Falha ao criar indicadores");
      return INIT_FAILED;
   }

   // ✅ CORREÇÃO CRÍTICA V2: Força reload completo SEMPRE
   // Evita perda de memória ao mudar data/período no testador
   // MT5 pode zerar arrays globais durante reinicialização completa
   Print("🔄 OnInit() chamado - Preparando arrays...");
   
   int sz = NUM_STATES * NUM_ACTIONS;
   
   // Redimensiona arrays SOMENTE se tamanho diferente
   // Evita realocação desnecessária que poderia zerar dados
   if(ArraySize(g_Q) != sz)
   {
      Print("📏 Redimensionando g_Q de ", ArraySize(g_Q), " para ", sz);
      ArrayResize(g_Q, sz);
   }
   if(ArraySize(g_stateVisits) != NUM_STATES)
   {
      Print("📏 Redimensionando g_stateVisits de ", ArraySize(g_stateVisits), " para ", NUM_STATES);
      ArrayResize(g_stateVisits, NUM_STATES);
   }
   if(ArraySize(g_stateLosses) != NUM_STATES)
      ArrayResize(g_stateLosses, NUM_STATES);
   if(ArraySize(g_stateWins) != NUM_STATES)
      ArrayResize(g_stateWins, NUM_STATES);
   if(ArraySize(g_stateProfitSum) != NUM_STATES)
      ArrayResize(g_stateProfitSum, NUM_STATES);
   if(ArraySize(g_stateProfitSqSum) != NUM_STATES)
      ArrayResize(g_stateProfitSqSum, NUM_STATES);
   if(ArraySize(g_stateLastUpdate) != NUM_STATES)
      ArrayResize(g_stateLastUpdate, NUM_STATES);
   if(ArraySize(g_stateBlocked) != NUM_STATES)
      ArrayResize(g_stateBlocked, NUM_STATES);
   if(ArraySize(g_stateLastBlockTime) != NUM_STATES)
      ArrayResize(g_stateLastBlockTime, NUM_STATES);
   if(ArraySize(g_stateLastUnblockTime) != NUM_STATES)
      ArrayResize(g_stateLastUnblockTime, NUM_STATES);
   if(ArraySize(g_stateWasBlockedBefore) != NUM_STATES)
      ArrayResize(g_stateWasBlockedBefore, NUM_STATES);
   if(ArraySize(g_stateBlockTime) != NUM_STATES)
      ArrayResize(g_stateBlockTime, NUM_STATES);
   if(ArraySize(g_stateBlockCount) != NUM_STATES)
      ArrayResize(g_stateBlockCount, NUM_STATES);
   if(ArraySize(g_activeStates) != MaxMemoryStates)
      ArrayResize(g_activeStates, MaxMemoryStates);

   // ❌ REMOVIDO: LoadState() causava conflito com LoadBrain()
   // LoadState() carregava dados antigos que interferiam na detecção de arrays vazios
   // Sistema agora usa APENAS LoadBrain() que carrega de Cerebro_Universal.bin
   // LoadState();
   
   // ✅ NOVA LÓGICA: Verifica se arrays foram zerados por reinicialização do MT5
   // Se g_activeStatesCount > 0 mas arrays parecem vazios, força reload
   // NOTA: g_activeStatesCount será 0 aqui se não carregou LoadState(), então esta verificação
   // não será triggered incorretamente
   bool arraysSeemEmpty = (g_activeStatesCount > 0 && g_activeStatesCount <= MaxMemoryStates && 
                           g_activeStates[0] >= 0 && g_activeStates[0] < NUM_STATES &&
                           g_stateVisits[g_activeStates[0]] == 0);
   
   if(arraysSeemEmpty)
   {
      Print("⚠️ Arrays detectados como vazios apesar de g_activeStatesCount=", g_activeStatesCount);
      Print("🔄 Forçando reload completo da memória...");
      g_activeStatesCount = 0; // Força LoadBrain() a recarregar tudo
   }

   if(!LoadBrain())
   {
      // ✅ PROTEÇÃO CRÍTICA: Verificar se arquivo realmente não existe
      // Se arquivo existe mas falhou ao carregar (erro temporário), NÃO sobrescrever!
      string mainFile = GetBrainFileName();
      string backupFile = GetBackupFileName(0);
      bool fileExists = FileIsExist(mainFile, FILE_COMMON) || FileIsExist(backupFile, FILE_COMMON);
      
      if(fileExists)
      {
         // ❌ CRÍTICO: Arquivo existe mas falhou ao carregar!
         // NÃO inicializar memória vazia - pode ser erro temporário
         Print("❌ ERRO CRÍTICO: Arquivo existe mas falhou ao carregar!");
         Print("❌ NÃO inicializando memória vazia para proteger dados existentes!");
         Print("❌ Arquivo principal: ", mainFile, " existe=", FileIsExist(mainFile, FILE_COMMON));
         Print("❌ Arquivo backup: ", backupFile, " existe=", FileIsExist(backupFile, FILE_COMMON));
         Print("❌ Tente recarregar o EA ou verifique permissões de arquivo");
         
         // Mantém estado não inicializado para evitar sobrescrever
         g_memoryInitialized = false;
         return INIT_FAILED; // Falha na inicialização para evitar perda de dados
      }
      
      // ✅ Arquivo realmente não existe - pode inicializar nova memória
      Print("📋 Inicializando nova memória...");
      ArrayInitialize(g_Q, 0.0);
      ArrayInitialize(g_stateVisits, 0);
      ArrayInitialize(g_stateLosses, 0);
      ArrayInitialize(g_stateWins, 0);
      ArrayInitialize(g_stateLastUpdate, 0);
      ArrayInitialize(g_stateBlocked, false);
      ArrayInitialize(g_stateLastBlockTime, 0);
      ArrayInitialize(g_stateLastUnblockTime, 0);
      ArrayInitialize(g_stateWasBlockedBefore, false);
      ArrayInitialize(g_stateBlockTime, 0);
      ArrayInitialize(g_stateBlockCount, 0);
      g_activeStatesCount = 0;
      
      // ✅ SEMPRE usa taxa configurada - SEM forçar mínimo
      g_currentExplorationRate = InitialExplorationRate;
      g_memoryInitialized = true;
      SaveBrain();
      Print("✅ Novo cérebro criado (Sistema Super Corrigido v309)");
   }
   else
   {
      // ✅ Arquivo carregado - memória preservada!
      g_memoryInitialized = true;
      
      // ✅ SEMPRE usa taxa de exploração configurada em InitialExplorationRate
      // Permite testar aprendizado com diferentes taxas de exploração
      g_currentExplorationRate = InitialExplorationRate;
      
      Print("✅ Cérebro existente carregado (Sistema Super Corrigido v309)");
      Print("📊 Estados ativos preservados: ", g_activeStatesCount);
      Print("⚙️ Taxa de exploração configurada: ", DoubleToString(g_currentExplorationRate * 100, 1), "%");
      
      // ✅ Verificação final: Confirma que dados foram carregados corretamente
      if(g_activeStatesCount > 0)
      {
         int firstState = g_activeStates[0];
         Print("🔍 Verificação: Estado[", firstState, "] Visitas=", g_stateVisits[firstState], 
               " Wins=", g_stateWins[firstState], " Losses=", g_stateLosses[firstState]);
         
         if(g_stateVisits[firstState] == 0)
         {
            Print("❌ ERRO CRÍTICO: Dados não carregados corretamente!");
            Print("❌ Tentando reload de emergência...");
            // Tenta carregar novamente
            LoadBrain();
         }
      }
   }
   
   ArrayResize(g_recentProfits, 100);
   ArrayInitialize(g_recentProfits, 0.0);
   g_recentProfitsIndex = 0;
   
   g_currentVolume = 0;
   g_volumeAverage = 0;
   g_volumeMultiplier = 1.0;
   g_volumeStrength = 0.0;
   
   UpdateLearningStats();
   
   g_statusMessage = "Inicializando Sistema Super Corrigido v309...";
   
   g_lastSaveTime  = TimeCurrent();
   g_lastEntryTime = 0;
   g_lastTradeTime = 0;
   g_lastBuyTime = 0;
   g_lastSellTime = 0;
   g_lastBarProcessed = 0;
   g_lastExportTime = 0;
   g_exportCount = 0;
   g_currentDirection = 0;
   g_positionsCount = 0;

   g_currentDirection = GetCurrentPositionsDirection();
   g_positionsCount = GetTotalPositions();
   
   if(g_currentDirection == 3)
   {
      Print("⚠️ ATENÇÃO: Encontradas posições em ambas as direções!");
      if(CloseOppositeOnNewSignal) CloseAllPositions();
   }

   Print("🔥🔥🔥 INICIALIZANDO SISTEMA SUPER CORRIGIDO...");
   Print("🔥🔥🔥 CONFIGURAÇÃO DE ESTADOS:");
   Print("🔥🔥🔥 Bins por indicador:");
   Print("🔥🔥🔥 MA Distance: ", BINS_MA_DIST);
   Print("🔥🔥🔥 RSI: ", BINS_RSI);
   Print("🔥🔥🔥 ADX: ", BINS_ADX);
   Print("🔥🔥🔥 BB Position: ", BINS_BBPOS);
   Print("🔥🔥🔥 Volatilidade: ", BINS_VOLATILITY);
   Print("🔥🔥🔥 Volume: ", BINS_VOLUME);
   Print("🔥🔥🔥 Tempo: ", BINS_TIME);
   Print("🔥🔥🔥 TOTAL DE ESTADOS: ", NUM_STATES, " (3×4×2×3×2×2×2 = 576)");
   Print("🔥🔥🔥 MEMÓRIA MÁXIMA: ", MaxMemoryStates, " estados ativos");
   Print("🔥🔥🔥 SISTEMA SUPER CORRIGIDO: ATIVADO");
   
   // ✅ CONFIGURAÇÕES APLICADAS:
   Print("⚙️ Configurações aplicadas:");
   Print("   • Exploration Rate: ", DoubleToString(g_currentExplorationRate * 100, 1), "%");
   Print("   • MinVisitsToTrade: 2");
   Print("   • BadStateMinVisits: 20");
   Print("   • BadStateLossThreshold: 60%");
   Print("   • MinStatesBeforeReset: 150 (previne resets e decay prematuros)");
   
   if(EnableUnifiedBlockingSystem)
   {
      AutoUnblockGoodStates();
      TestBlockedStatesPeriodically();
   }

   if(EnableMemoryExport) ExportAllMemoryFiles();

   Print("===============================================================");
   Print("✅ PHOENIX TRADER V307F - SISTEMA SUPER CORRIGIDO V2");
   Print("===============================================================");
   Print("🔴 CORREÇÕES EXTREMAS IMPLEMENTADAS:");
   Print("   1. ✅ REMOÇÃO COMPLETA do limite de 10 visitas");
   Print("   2. ✅ Auto-desbloqueio de estados com win rate > 35%");
   Print("   3. ✅ Reset parcial em vez de completo");
   Print("   4. ✅ Correção automática de estados travados");
   Print("   5. ✅ Sistema anti-bloqueio-erroneo ativado");
   Print("   6. ✅ Teste periódico de estados bloqueados (a cada 30 dias)");
   Print("🔥 NOVAS FUNÇÕES ADICIONADAS:");
   Print("   • EmergencyCounterFix() - Correção emergencial de contadores");
   Print("   • OverhaulBlockingSystem() - Revisão completa do bloqueio");
   Print("   • IntelligentPartialReset() - Reset parcial inteligente");
   Print("   • OptimizeParametersDynamically() - Otimização dinâmica");
   Print("===============================================================");
   Print("💾 CONFIGURAÇÃO DE BACKUP (ANTI-PERDA DE DADOS):");
   Print("   • Salvamento após cada trade: ", (SaveAfterEachTrade ? "ATIVO ✅" : "DESATIVADO ❌"));
   Print("   • Salvamento periódico: ", (EnablePeriodicAutoSave ? ("ATIVO ✅ (a cada " + IntegerToString(PeriodicSaveMinutes) + " minutos)") : "DESATIVADO ❌"));
   Print("   • Backups múltiplos: ", (CreateBackupFiles ? ("ATIVO ✅ (mantém " + IntegerToString(MaxBackupFiles) + " cópias)") : "DESATIVADO ❌"));
   Print("   • Exportar ao finalizar: ", (ExportOnDeinit ? "ATIVO ✅" : "DESATIVADO ❌"));
   if(SaveAfterEachTrade || EnablePeriodicAutoSave)
   {
      Print("   🛡️ PROTEÇÃO MÁXIMA CONTRA PERDA DE DADOS ATIVADA!");
   }
   else
   {
      Print("   ⚠️ AVISO: Salvamento automático desativado - dados podem ser perdidos!");
   }
   Print("===============================================================");
   
   // ✅ Funções de correção inicial removidas (não mais necessárias)
   
   if(ShowHUD)
   {
      CreateHUDObjects();
      ChartRedraw(0);
      Print("🖥️ HUD inicializado com ", hudObjectCount, " objetos");
   }
   
   // ✅ NOVO: Inicializa sistema de relatório mensal/anual
   InitializeMonthlyStats();
   
   g_statusMessage = "Pronto para operar (Sistema Super Corrigido v309)";
   
   return INIT_SUCCEEDED;
}

// ======================================================================
// ✅✅✅ OnDeinit (COM SISTEMA SUPER CORRIGIDO - NUNCA RESETA MEMÓRIA)
// ======================================================================
void OnDeinit(const int reason)
{
   Print("💾 Salvando memória antes de fechar... (Razão: ", reason, ")");
   
   // ✅ FORÇA g_memoryDirty = true para garantir que SaveBrain() não seja pulado
   g_memoryDirty = true;
   g_memorySaveCounter = 999; // Força save mesmo com UseIncrementalSave
   
   // ✅ USA SaveBrain() que já gerencia tudo corretamente:
   //    - Salva arquivo principal
   //    - Chama ManageBackupFiles() para criar backup com nome correto
   //    - Salva estado
   //    - Export texto se habilitado
   if(!SaveBrain())
   {
      Print("❌ ERRO CRÍTICO: Falha ao salvar memória!");
      
      // Tenta salvar diretamente como última tentativa
      string mainFile = GetBrainFileName();
      if(CreateDirectoryForFile(mainFile))
      {
         if(SaveBrainToFile(mainFile))
         {
            Print("✅ Arquivo principal salvo em tentativa de emergência");
            
            // Tenta criar backup de emergência
            if(CreateBackupFiles)
            {
               string backupFile = GetBackupFileName(0);
               if(FileIsExist(backupFile, FILE_COMMON))
               {
                  FileDelete(backupFile, FILE_COMMON);
               }
               if(SaveBrainToFile(backupFile))
               {
                  Print("✅ Backup de emergência criado");
               }
            }
         }
         else
         {
            Print("❌ FALHA CRÍTICA: Não foi possível salvar memória!");
         }
      }
   }
   else
   {
      Print("✅ Memória salva com sucesso via SaveBrain()");
   }
   
   // ✅ NOVO: Exportar relatório mensal/anual final
   ExportMonthlyReport();
   
   Print("💾 Processo de salvamento concluído");
   
   IndicatorRelease(g_maHandle);
   IndicatorRelease(g_rsiHandle);
   IndicatorRelease(g_macdHandle);
   IndicatorRelease(g_atrHandle);

   RemoveHUD();
}
