# BREU — Livro de Memórias & Diário de Desenvolvimento

> Este documento registra toda a visão criativa, regras de gameplay, decisões técnicas, arquitetura de arquivos e próximos passos do projeto **BREU** para que o desenvolvimento possa ser retomado exatamente de onde parou em qualquer máquina ou sessão.

---

## 1. Conceito & Identidade Visual
* **Nome do Jogo:** **BREU**
* **Engine:** Godot **4.5.1** (Forward Plus)
* **Estética:** Terror psicológico 3D estilo **PlayStation 1 / GameCube** (resolução interna `320x240`, *Bayer 4x4 dithering*, filtro `Nearest` sem anti-aliasing, texturas granuladas procedurais e vinheta claustrofóbica dinâmica que fecha ao agachar).
* **Premissa:** Uma madrugada de tempestade e apagão. O elevador parou e a porta do **Térreo** está travada por uma **Trava Noturna de 4 dígitos**. Você começa no **10º Andar** e precisa descer pela escadaria pressurizada sobrevivendo às assombrações, ao Perseguidor e caçando as **4 pistas enigmáticas pintadas em sangue** (`◈`, `✕`, `☾`, `▲`) escondidas pelos andares (incluindo dentro das Antecâmaras) para destravar a saída.
* **Pilares de Terror:**
  * **Escuridão & Sensor de Presença:** Iluminação depende das lâmpadas fluorescentes por sensor de movimento. Parado por ~4,6s, a luz apaga (*click*) e entra uma pressão de silêncio nos ouvidos; ao voltar a se mexer, o LED pisca e há um delay de ~0,34s antes de a lâmpada reacender.
  * **Prédio Físico Real (Euclidiano):** Todos os **10 andares (10º ao Térreo)** existem fisicamente empilhados sem teletransporte. A grade de ferro só existe no topo (**10º Andar**, rente ao piso e fechada atrás). Nos demais andares você sobe e desce livremente.
  * **Morte Seca (Opção A):** Sem telas vermelhas explicativas. Susto 3D rápido com glitch PS1 → corte seco para o preto absoluto → você acorda ofegante de volta no **10º Andar**.

---

## 2. Regras de Gameplay & Narrativa (Estado Atual)

### A. A Trava Noturna do Térreo & Pistas Enigmáticas em Sangue
* No **Térreo (0º Andar)**, ao pressionar **`[E]`** na saída, abre um **Teclado Numérico de 4 Dígitos** (clique ou teclado `0–9`, `Backspace`, `Enter`, `ESC`).
* Um bilhete ao lado mostra a ordem dos 4 símbolos: **`◈   ✕   ☾   ▲`**.
* A cada partida, 4 números aleatórios são sorteados e escondidos em 4 andares diferentes (9º..1º) com **caligrafia trêmula feita à mão em sangue** (com gotas escorrendo e marcas de mãos) em 4 esconderijos: parede de concreto do patamar, **parede interna de uma Antecâmara destrancada**, abaixo de um pôster, e próximo à janela noturna/quadro de luz.
* **Bloco de Notas (`[TAB]`):** Ao chegar perto de uma pista, ela é anotada automaticamente para consulta rápida com `TAB`.
* **Storytelling Ambiental:** Cada andar (10º ao Térreo) possui um **Mural de Avisos único** contando a história daquela madrugada, além de decorações variadas por andar (múltiplos pôsteres retrô, caixas de mudança, balde e esfregão do zelador, cadeira velha, poças d'água, interfone vermelho, hidrante e quadro de luz).

### B. As 10 Anomalias + 2 Micro-Eventos
Sorteio via **baralho embaralhado** a cada partida. Se ignorar uma assombração e passar reto pelo 2º lance → morte 3D (*"O Puxão no Breu"*). Para sobreviver, **suba de volta para o andar de cima e espere a luz do andar assombrado apagar** (70% de chance de purificar, 30% de trocar para outra assombração):
1. `DOOR_WINDOW_WATCHER`: Rosto pálido no vidro da porta corta-fogo (`*TOC-TOC*` e batida forte se ignorado).
2. `STATIC_DARK_FIGURE`: Vulto parado no patamar intermediário que vira e desce as escadas abaixo com passos ecoando.
3. `HANDS_ON_DOOR`: Porta entreaberta com mãos 3D segurando a beirada que puxam e fecham a porta sozinha.
4. `INVISIBLE_CAST_SHADOW`: Sombra humana 3D real (`SHADOWS_ONLY`) projetada na parede sem nenhum corpo visível.
5. `HAUNTED_POSTER_WINDOW`: Pôsteres se deformam + figura pálida com mãos batendo na janela noturna gradeada.
6. `UPPER_FLOOR_STALKER`: Luz do andar de cima acende sozinha e passos descem atrás de você.
7. `HAUNTED_DECOR_POSTERS`: Todos os pôsteres do andar ficam assombrados, placa `↓ SAÍDA` vira `↑ NÃO DESÇA`, cavalete amarelo derrubado e LED do quadro de luz vermelho.
8. `RED_LIGHT_SHOCK`: As duas luzes do andar acendem subitamente em vermelho-sangue forte com acorde/impacto assustador e tremor de câmera.
9. `RINGING_INTERCOM`: O interfone vermelho na parede toca sozinho (`*TRIIIIIM!*`); ao atender (`[E]`), sai estática/voz distorcida e as luzes apagam.
10. `BROKEN_SENSOR_DARK`: O sensor do patamar intermediário dá um curto-circuito com faísca e não acende, deixando breu total com respiração oca lá embaixo.

* **Micro-Eventos:**
  * **Relâmpagos na Janela:** Trovões distantes disparam clarões azulados nas janelas do patamar (às vezes revelando um rosto colado do lado de fora por 0,16s!).
  * **Passos Atrasados ("O Eco"):** Raramente, quando você para de andar na escada, ouve mais 2 passos secos colando atrás das suas costas.

### C. O Perseguidor Progressivo & A Antecâmara (Defesa Opção C)
* **Silhueta Macabra:** Mais alto (`1.18x`), braços finos e compridos, pescoço torto (20°) e rosto pálido maior.
* **Evento Guiado por Áudio:** Porta bate com força 2 andares abaixo → passos humanos lentos subindo (com atenuação real por distância e filtro abafado de longe, acendendo os sensores lá embaixo!) → corra para uma Antecâmara destrancada e feche a porta (`[E]`).
* **Defesa (Opção C):** Agache (`CTRL`) no ponto cego (enquanto agachado, `[E]` nunca abre a porta!). A luz lá fora permanece acesa enquanto ele está na janela. Ele encosta o rosto de súbito no vidro (`*TUM!*`) e pode forçar a porta → **segure `[E]`** para travar contra ele até ele desistir, subir ao andar acima e bater a porta agressivamente (sinal sonoro para sair).
* **Porta de Trás da Antecâmara:** Pausada enquanto o Perseguidor está ativo. Se demorar depois que está seguro: 9s → `*tok... tok... tok...*` → 15s mais perto → 20s maçaneta gira → 24,5s morte 3D.

---

## 3. Áudio & Acústica DSP
* **Barramentos no `AudioServer`:** `Stairwell` (Reverb de concreto), `Muffled` (Low-Pass 920Hz + Reverb), `Scare` (Overdrive PS1).
* **Acústica Dinâmica:** Fechar a porta da Antecâmara abafa o drone externo e deixa seus passos secos (`Master`), voltando ao eco (`Stairwell`) ao abrir a porta.
* **Ambiente Vivo:** Chuva noturna 3D nas janelas, goteiras nos canos, estalos térmicos, trovões distantes, motor/freio de elevador velho, batimento cardíaco dinâmico com o Perseguidor e pressão de silêncio no breu.

---

## 4. Menus, Controles & Atalhos
* **Menu Principal & Pausa (`ESC`):** Câmera 3D ao vivo na escadaria, `JOGAR / CONTINUAR`, `REINICIAR`, `CONTROLES`, sliders de **Sensibilidade do Mouse** e **Volume Geral**, e `SAIR`.
* **Controles:** `WASD` (andar), `SHIFT` (correr), `CTRL` / `C` (agachar), `E` / Clique (portas / interfone / travar porta), `TAB` (Bloco de Notas), `ESC` (Pausa).
* **Debug:** `F1` (alterna as 10 anomalias no andar atual), `F2` (dispara o Perseguidor 2 andares abaixo).

---

## 5. Próximos Passos Possíveis
* **Fase 2 (Opcional no futuro):** Aumentar agressividade das luzes/Perseguidor quando o jogador volta subindo do Térreo após descobrir a trava.
* **Samples Reais CC0:** Substituir passos/porta de ferro por gravações `.wav`/`.ogg` reais mantendo os barramentos DSP.
* **Tela Final / Cutscene de Saída:** Mostrar um vislumbre da rua chuvosa ao abrir a porta do Térreo!
