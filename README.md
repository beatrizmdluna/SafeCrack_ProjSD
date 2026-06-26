

Pular para o conteúdo
Como usar o E-mail de Centro de Informatica - UFPE com leitores de tela
Ativar as notificações na área de trabalho para o E-mail de Centro de Informatica - UFPE.
   OK  Agora não(a)

3 de 1.031
(sem assunto)
Caixa de entrada

Samia Maria de Freitas Gonzaga
Anexos
16:58 (há 1 hora)
para mim


 1 anexo
  •  Verificados pelo Gmail
# SafeCrack FSM — README

## 1. Descrição detalhada de como os requisitos foram implementados

### Arquitetura da FSM

A FSM foi implementada com 7 estados usando codificação *one-hot* de 7 bits (`logic [6:0]`), o que melhora a confiabilidade em FPGAs ao reduzir o risco de transições espúrias. Os estados são:

| Estado | Código | Função |
|---|---|---|
| `EDIT_D0` | `7'b0000001` | Edição do 1º dígito (HEX3) |
| `EDIT_D1` | `7'b0000010` | Edição do 2º dígito (HEX2) |
| `EDIT_D2` | `7'b0000100` | Edição do 3º dígito (HEX1) |
| `EDIT_D3` | `7'b0001000` | Edição do 4º dígito (HEX0) |
| `VERIFICACAO` | `7'b0010000` | Comparação com a senha correta |
| `SUCESSO` | `7'b0100000` | Feedback de senha correta |
| `FAIL` | `7'b1000000` | Feedback de senha incorreta |

A FSM é separada em dois blocos canônicos: lógica sequencial (`always_ff`) e lógica combinacional de próximo estado/saída (`always_comb`).

---

### Entradas e controle (botões ativos em baixo)

| Botão | Função |
|---|---|
| `KEY[0]` | Reset assíncrono: retorna a `EDIT_D0` e zera todos os dígitos |
| `KEY[1]` | Confirma o dígito atual e avança para o próximo |
| `KEY[2]` | Incrementa o dígito em edição (wrap: 9 → 0) |
| `KEY[3]` | Decrementa o dígito em edição (wrap: 0 → 9) |

Como os botões são ativos em baixo, os sinais são invertidos antes do uso. Para evitar que um único clique cause múltiplos disparos, foi implementada **detecção de borda de subida** via dois registradores:

```verilog
btn_prev <= ~KEY[3:1];                  // salva estado anterior (ativo alto)
btn_edge = (~KEY[3:1]) & (~btn_prev);   // pulso apenas na transição 0→1
```

`btn_edge[i]` vale `1` somente no ciclo de clock imediatamente após o botão ser pressionado.

---

### Fluxo de edição de senha

Nos estados `EDIT_D0` a `EDIT_D3`, o usuário ajusta cada dígito com `KEY[2]`/`KEY[3]` e avança com `KEY[1]`. Os valores são armazenados nos registradores `d0`–`d3`, e suas cópias combinacionais `next_d0`–`next_d3` garantem atualização síncrona na borda de clock.

---

### Verificação

Ao confirmar `EDIT_D3`, o contador de tempo é zerado e a FSM entra em `VERIFICACAO`. Nesse estado (duração: 1 ciclo de clock), a concatenação `{d0,d1,d2,d3}` é comparada com `{SENHA_0,SENHA_1,SENHA_2,SENHA_3}` (senha fixa: **6767**). O resultado direciona para `SUCESSO` ou `FAIL`.

---

### Temporizador de feedback

Um contador de 29 bits (`timer_cnt`) a 50 MHz controla o tempo de exibição do feedback:

- `SUCESSO`: LEDs verdes acesos por **5 segundos** (50.000.000 × 5 = 250.000.000 ciclos)
- `FAIL`: LEDs vermelhos acesos por **3 segundos** (50.000.000 × 3 = 150.000.000 ciclos)

Após o tempo, a FSM retorna automaticamente a `EDIT_D0` com todos os dígitos zerados.

---

### Displays 7-segmentos

A função `s7seg()` converte um valor BCD (0–9) para a codificação de cátodo comum do display da placa. O mapeamento de exibição é:

| Display | Conteúdo |
|---|---|
| `HEX3` | Dígito `d0` (1º a ser definido) |
| `HEX2` | Dígito `d1` |
| `HEX1` | Dígito `d2` |
| `HEX0` | Dígito `d3` (último) |
| `HEX4` | Número do dígito ativo (1–4); apagado fora dos estados de edição |

---

## 2. Diagrama de estados

![Diagrama de estados da FSM](./diagrama_estados.png)

---

## 3. Diagramas de tempo da simulação (waveforms)

### Cenário A — Senha correta (6767)

O usuário parte do estado `EDIT_D0` e pressiona `KEY[2]` seis vezes para setar `d0 = 6`, confirma com `KEY[1]`, pressiona `KEY[2]` sete vezes para `d1 = 7`, confirma, repete para `d2 = 6` e `d3 = 7`. Ao confirmar o último dígito, a FSM transita para `VERIFICACAO` por um ciclo de clock e em seguida para `SUCESSO`. Todos os LEDs verdes (`LEDG = 9'h1FF`) ficam acesos durante 5 segundos; após o timeout, a FSM retorna a `EDIT_D0` com todos os dígitos zerados.

![Waveform — Senha correta](./waveform_sucesso.png)

---

### Cenário B — Senha incorreta e reset manual

O usuário insere qualquer combinação diferente de 6767. Após confirmar o 4º dígito, a FSM transita para `VERIFICACAO` e em seguida para `FAIL`. Todos os LEDs vermelhos (`LEDR = 18'h3FFFF`) ficam acesos durante 3 segundos; após o timeout, a FSM retorna a `EDIT_D0`. Caso `KEY[0]` seja pressionado em qualquer momento (inclusive durante `FAIL`), o reset assíncrono leva a FSM imediatamente a `EDIT_D0`, apagando todos os dígitos e LEDs.

![Waveform — Senha incorreta](./waveform_fail.png)

---

## 4. Known Issues (Bugs conhecidos)

**Bug 1 — Sem debounce de hardware**
A implementação usa apenas detecção de borda por software. Botões mecânicos podem gerar múltiplos pulsos rápidos (*bouncing*), o que pode causar incrementos/decrementos extras em um único clique físico. Solução típica: acrescentar um contador de debounce de aproximadamente 20 ms.

**Bug 2 — Ausência de sincronizador de entrada**
Os sinais `KEY[3:1]` vão diretamente dos pinos da FPGA para a lógica de detecção de borda sem passar por flip-flops sincronizadores. Isso expõe o design ao risco de **metaestabilidade** quando a borda do botão ocorre próxima à borda do clock.

**Bug 3 — Senha visível durante o feedback**
Durante os estados `SUCESSO` e `FAIL`, os displays `HEX3`–`HEX0` continuam exibindo os dígitos inseridos pelo usuário, expondo a senha enquanto o feedback está ativo.

**Bug 4 — `timer_cnt` não é zerado ao retornar a `EDIT_D0` via timeout**
Quando a FSM sai de `SUCESSO` ou `FAIL` pelo estouro do timer, o registrador `timer_cnt` não é resetado — ele retém o valor final da contagem. No código atual isso não causa problema funcional, pois nenhum estado de edição utiliza o timer. Contudo, uma extensão futura do projeto poderia ser afetada por esse valor residual.
README.md
Exibindo README.md.
