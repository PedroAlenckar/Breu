# BREU — Livro de Memórias & Diário de Desenvolvimento

> Este documento registra toda a visão criativa, regras de gameplay, decisões técnicas, arquitetura de arquivos e próximos passos do projeto **BREU** para que o desenvolvimento possa ser retomado exatamente de onde parou em qualquer máquina ou sessão.

---

## 1. Conceito & Identidade Visual
* **Nome do Jogo:** **BREU**
* **Engine:** Godot **4.5.1** (Forward Plus)
* **Estética:** Terror psicológico 3D estilo **PlayStation 1 / GameCube** (resolução interna `320x240`, *Bayer 4x4 dithering*, filtro `Nearest` sem anti-aliasing, texturas granuladas procedurais e vinheta claustrofóbica).
* **Premissa:** Você está preso na escada de emergência pressurizada de um prédio escuro, começando no **10º Andar**, e precisa descer até o **Térreo (0º Andar)** para escapar.
* **Pilares de Terror:**
  * **Escuridão & Sensor de Presença:** A iluminação depende exclusivamente das luminárias fluorescentes acionadas por sensor de movimento. Se ficar parado por ~4,6s, a luz apaga (*click*) e você fica no breu; ao voltar a se mexer, há um pequeno delay (~0,34s) com o LED do sensor piscando antes de a lâmpada piscar e reacender.
  * **Prédio Físico Real (Euclidiano):** Os **10 andares (10º ao Térreo)** existem fisicamente empilhados sem teletransporte. A grade de ferro só existe no topo (**10º Andar**). Nos demais andares você sobe e desce livremente.
  * **Morte Seca (Opção A):** Sem telas vermelhas explicativas ou textos de "Game Over". Quando você morre, acontece um susto 3D rápido com distorção PS1 → corte seco para o preto absoluto → você acorda ofegante de volta no **10º Andar**.

---

## 2. Regras de Gameplay (Estado Atual)

### A. Assombrações & Purificação pelo Breu
* Ao descer para um andar, observe atentamente os detalhes (porta corta-fogo, pôsteres, quadro de avisos, placa direcional `↓ SAÍDA`, cavalete de piso molhado, janela noturna, patamar intermediário, sombras e som).
* **Se houver uma assombração no andar:**
  * **NÃO continue descendo.** Se você passar reto pelo 2º lance de escada ignorando a assombração, as luzes estouram (`*POP!*`), há meio segundo de breu, um sussurro na nuca e a câmera vira 180º à força para o susto 3D (*"O Puxão no Breu"*).
  * **Como sobreviver:** Dê meia-volta e **suba para o andar de cima**, esperando a luz do sensor do andar assombrado apagar (`*CLICK*`). Quando o andar entra no breu total, ele é re-sorteado: **70% de chance de ficar purificado (limpo)** e **30% de chance de trocar para outra assombração** (mantendo a paranoia ao descer de novo).

### B. As 7 Anomalias Implementadas
Sorteio via **baralho embaralhado** a cada partida (evita repetições seguidas):
1. `DOOR_WINDOW_WATCHER`: Rosto pálido observando atrás do vidro da porta corta-fogo; dá batidas no vidro (`*TOC-TOC*`) e bate forte na porta se ignorado.
2. `STATIC_DARK_FIGURE`: Vulto escuro parado no patamar intermediário; ao se aproximar, ele vira e desce as escadas abaixo com passos ecoando.
3. `HANDS_ON_DOOR`: Porta corta-fogo começa entreaberta com mãos 3D segurando a beirada; quando você se aproxima ou começa a descer, as mãos recolhem e a porta fecha sozinha com barulho de trava.
4. `INVISIBLE_CAST_SHADOW`: Sombra humana 3D real (`SHADOWS_ONLY`) projetada pela lâmpada fluorescente normal na parede de concreto, inclinando a cabeça — sem nenhum corpo visível no patamar.
5. `HAUNTED_POSTER_WINDOW`: Pôster de retrato na parede se deforma, quadro de avisos muda e uma figura pálida com mãos no vidro observa e bate na janela noturna gradeada do patamar intermediário.
6. `UPPER_FLOOR_STALKER`: Quando você começa a descer, a luz do **andar de cima** acende sozinha e algo começa a descer a escada atrás de você com passos pesados.
7. `HAUNTED_DECOR_POSTERS`: Ambos os pôsteres (retrato + diagrama de rota de fuga) ficam assombrados, a placa `↓ SAÍDA` vira `↑ NÃO DESÇA` em vermelho, o cavalete amarelo de piso molhado aparece derrubado e o LED do quadro de luz fica vermelho.

### C. O Perseguidor Progressivo & A Antecâmara (Defesa Opção C)
* **Portas Corta-Fogo:** Portas com anomalias na própria porta ficam **sempre trancadas**. As demais são sorteadas aleatoriamente a cada partida (garantindo no máximo 2 trancadas seguidas).
* **Evento do Perseguidor (Raro & Guiado por Áudio):**
  1. Você ouve uma **porta metálica bater com força 2 andares abaixo**.
  2. Começam **passos humanos lentos subindo a escada** (abafados e baixinhos de longe, ficando mais altos e nítidos conforme ele sobe e acende os sensores dos andares abaixo!).
  3. Você precisa correr até uma **Antecâmara destrancada**, entrar e fechar a porta (`[E]`).
  4. **Defesa (Opção C):**
     * **Agache (`CTRL` ou `C`)** no ponto cego (fora da visão da janelinha de vidro). Enquanto agachado, apertar `[E]` **nunca abre a porta** (apenas trava!).
     * A luz lá fora permanece acesa enquanto ele espia na janela.
     * Se ele testar/forçar a porta (a porta treme com som de impacto), **segure `[E]`** para mantê-la travada até ele desistir.
  5. Ao desistir, ele sobe para o andar acima (os passos vão se afastando) e **bate a porta do andar de cima agressivamente** — sinal sonoro de que está seguro sair!
* **Ameaça da Porta Traseira da Antecâmara:**
  * Fica **100% pausada** enquanto o Perseguidor está ativo no prédio.
  * Depois que o caminho está livre, se você ficar escondido no quarto por tempo demais: 9s → `*tok... tok... tok...*` suave e abafado → 15s mais perto → 20s a maçaneta gira visivelmente → 24,5s a porta de trás abre (morte 3D arrastado para o escuro).

---

## 3. Controles & Atalhos de Desenvolvimento
* **`W A S D` / Setas:** Andar
* **`SHIFT`:** Correr
* **`CTRL` ou `C`:** Agachar (silencioso + ponto cego na Antecâmara + impede abrir porta por engano)
* **`E` ou `Clique Esquerdo`:** Abrir/Fechar porta (em pé) | Travar porta (agachado ou quando forçada)
* **`ESC`:** Soltar/Capturar cursor do mouse
* **`F1` (Debug):** Alterna entre as 7 anomalias no andar atual
* **`F2` (Debug):** Dispara o evento do Perseguidor 2 andares abaixo para teste imediato

---

## 4. Arquitetura de Arquivos do Projeto
* [`project.godot`](project.godot) — Configurações do Godot 4.5 (Viewport 1280x720, Nearest filter, sem MSAA).
* [`scenes/main.tscn`](scenes/main.tscn) — Cena principal que instancia `scripts/main.gd`.
* [`shaders/ps1_post.gdshader`](shaders/ps1_post.gdshader) — Post-processing PS1 (320x240, Bayer 4x4 dithering, scanlines, vinheta e uniform `scare_intensity` para glitch/RGB split nos sustos).
* [`scripts/audio_synth.gd`](scripts/audio_synth.gd) — Motor de áudio procedural baseado em ruído multi-banda filtrado + 3 barramentos DSP (`Stairwell` com Reverb de concreto, `Muffled` com Low-Pass + Reverb, `Scare` com Overdrive).
* [`scripts/procedural_textures.gd`](scripts/procedural_textures.gd) — Gerador de texturas retrô (concreto, degraus, porta corta-fogo, mãos arrastadas, rosto pálido, pôsteres normal/assombrado).
* [`scripts/player_controller.gd`](scripts/player_controller.gd) — Controle em primeira pessoa, headbob, agachar (`CTRL`), tremor de câmera e flash de jumpscare.
* [`scripts/stairwell_segment.gd`](scripts/stairwell_segment.gd) — Módulo de cada andar físico (16 degraus por lance, sensores de movimento com delay, Antecâmara, decorações, anomalias e lógica de purificação no breu).
* [`scripts/main.gd`](scripts/main.gd) — Constrói o prédio físico de 10 andares, gerencia baralho de anomalias, máquina de estados do Perseguidor (com atenuação dinâmica por distância) e sequências de morte 3D.

---

## 5. Próximos Passos & Ideias para Continuar Depois
* **Áudio (Polimento Final):** Considerar importar samples reais `.wav`/`.ogg` gratuitos (ex: freesound.org, CC0) para passos no concreto, porta corta-fogo metálica pesada e batidas, mantendo os barramentos DSP (`Stairwell` / `Muffled`) que já estão configurados!
* **Mais Decorações & Vida:** Adicionar manchas de infiltração/goteira com som pingando, mais variações de pôsteres/avisos de condomínio, luz de emergência verde piscando no teto, caixa de correio/extintores variados ou lixo sutil pelos degraus.
* **Novas Anomalias:**
  * Lâmpada do patamar de baixo acendendo sozinha sem ninguém lá.
  * Passos ecoando 1 degrau atrás de você quando você para de andar.
  * Telefone de emergência / interfone na parede tocando no escuro.
* **Menu Principal & Sombras/Polimento:** Criar uma tela inicial minimalista estilo PS1 ("BREU — Pressione qualquer tecla") e uma tela de vitória mais atmosférica ao abrir a porta do Térreo.
