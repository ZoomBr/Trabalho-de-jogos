# Documentação técnica: Chaves do Reino

Este documento explica **como cada parte do jogo funciona**, para a dupla conseguir apresentar e defender o projeto. Todos os scripts também têm comentários em português.

---

## 1. Visão geral da arquitetura

```
Menu principal ──► Escolha do herói ──► Intro ──► Fase 1 ──► Intro ──► Fase 2 ──► Intro ──► Fase 3 ──► Tela final
      ▲                                   ▲          │                   │                   │
      │                                   └─ derrota ┴───────────────────┴───────────────────┘
      └──────────────────────────── (Tela final: "Tentar de novo" ou "Menu")
```

Três **autoloads** (Projeto → Configurações → Autoload) ficam vivos durante o jogo inteiro:

| Autoload | Arquivo | Função |
|----------|---------|--------|
| `Global` | `scripts/autoload/global.gd` | Estado da campanha: fase atual, **classe escolhida**, pontos, vidas, **nível, XP e melhorias**, estatísticas, recorde e opções de áudio. Salva recorde e opções em `user://chaves_do_reino.cfg` com `ConfigFile`. |
| `Sons` | `scripts/autoload/sons.gd` | Toca efeitos sonoros e músicas. Tem 10 canais (`AudioStreamPlayer`) usados em rodízio, para vários sons tocarem ao mesmo tempo. |
| `Transicao` | `cenas/autoload/transicao.tscn` | Um `CanvasLayer` com um retângulo preto que escurece, troca a cena e clareia (efeito *fade*). Se outro pedido de troca chega no meio do fade, ele fica guardado e é feito em seguida. |

Qualquer script pode chamar, por exemplo, `Sons.tocar("moeda")` ou `Global.concluir_fase(...)`.

**"Tentar de novo":** quando uma fase começa, `Global.iniciar_fase_atual()` tira uma "foto" dos pontos, do nível, da XP, das melhorias e das vidas. Se o jogador perde, `tentar_novamente()` devolve tudo como estava, então ninguém perde as melhorias ganhas nas fases anteriores, mas também não fica com as da tentativa que falhou.

---

## 2. Configuração de pixel art

Em **Projeto → Configurações**:

- Viewport de **320×180** com modo de esticar `viewport` e **escala inteira** (`scale_mode = integer`). A janela de 1280×720 mostra cada pixel do jogo como um quadrado 4×4 perfeito.
- Filtro de textura **Nearest**, para os pixels não ficarem borrados.
- **Snap 2D** de transformações e vértices, para os sprites não ficarem em meio pixel.
- A fonte pixel foi importada **sem antialiasing**.

---

## 3. Camadas de física (colisão)

| Nº | Nome | Quem está nela | Quem colide com ela |
|:--:|------|----------------|---------------------|
| 1 | mundo | árvores, pedras, muros e portões | jogador, inimigos, projéteis |
| 2 | jogador | o herói | áreas de dano, itens, projéteis inimigos |
| 3 | inimigos | inimigos comuns e chefões | golpes e projéteis do jogador |
| 4 | itens | moedas, chaves, corações, portal e bandeira | — |
| 5 | projeteis_jogador | flechas e bolas de fogo | — |
| 6 | agua | tiles de água e de lava | jogador e inimigos que andam |
| 7 | projeteis_inimigos | gosma, flechas, pedras e espíritos | o **golpe de espada** (para destruí-los) |

A água fica numa **camada separada** (6) de propósito: jogador e slimes não conseguem entrar nela, mas os **projéteis passam por cima**, porque a máscara deles não inclui a camada 6. O morcego e o fantasma têm máscara 0 e por isso **atravessam tudo**.

---

## 4. Cenário: TileSet e TileMapLayer

Cada fase tem seu mapa em `cenas/mundos/mundo_fase_N.tscn`, com 5 camadas `TileMapLayer`:

| Camada | Conteúdo | Colisão |
|--------|----------|---------|
| `Chao` | grama, lama ou piso de pedra (4 variações) | não |
| `Caminho` | trilhas de terra ou tapete | não |
| `Agua` | água ou lava, com bordas | sim (camada física 1 do TileSet → camada 6 "agua") |
| `Decoracao` | tronco das árvores, pilares, pedras, barris, muros | sim (camada física 0 do TileSet → camada 1 "mundo") |
| `Copas` | copas das árvores e topo dos pilares | não. Tem `z_index = 10`, então o jogador passa **por trás** delas. |

As trilhas e a água usam **peças de borda automáticas**: existem 16 versões de cada, uma para cada combinação de vizinhos. É o mesmo princípio dos "terrenos" do Godot.

---

## 5. Classes de herói (dados separados do código)

A classe do herói é um **Resource** personalizado:

```gdscript
class_name ClasseHeroi extends Resource   # scripts/dados/classe_heroi.gd
enum Ataque { ESPADA, BOLA_DE_FOGO, FLECHA }
enum Poder { GIRO_DA_ESPADA, EXPLOSAO_ARCANA, CHUVA_DE_FLECHAS }
@export var nome, descricao, textura, vida_inicial, vida_maxima, velocidade,
            dano, cadencia, ataque, poder, recarga_poder, icone_poder ...
```

Existem três arquivos desse tipo: `recursos/classes/guerreiro.tres`, `mago.tres` e `arqueira.tres`. Ao abrir um deles no Godot, o **Inspetor mostra todos os atributos** e dá para balancear o jogo sem tocar em código.

| Classe | Vida inicial / máx. | Velocidade | Dano | Cadência (s) | Recarga do poder (s) |
|--------|:---:|:---:|:---:|:---:|:---:|
| Guerreiro | 5 / 7 | 78 | 2 | 0,32 | 6 |
| Mago | 3 / 5 | 82 | 2 | 0,48 | 7 |
| Arqueira | 4 / 6 | 96 | 1 | 0,22 | 6 |

A tela `selecao_classe.tscn` mostra as três cartas, lendo os dados de `Global.CLASSES`. Ao escolher, chama `Global.novo_jogo(fase, id_da_classe)`.

---

## 6. Jogador (`scripts/personagens/jogador.gd`)

- **Aparência:** no `_ready()`, o script monta as animações (`SpriteFrames`) a partir da folha de sprites da classe (4 quadros × 3 direções). Por isso existe **uma só cena de jogador** para as três classes.
- **Movimento:** `Input.get_vector()` lê as 8 direções; a velocidade muda aos poucos com `move_toward` (aceleração suave). A velocidade final é `classe.velocidade × Global.mult_velocidade`.
- **Animação em 4 direções:** compara `abs(x)` com `abs(y)` da última direção para escolher `baixo`, `cima` ou `lado`, e espelha o sprite (`flip_h`) para a esquerda.
- **Ataque básico** (`_atacar`), escolhido com `match classe.ataque`:
  - **Espada:** instancia `golpe_espada.tscn` como filho do jogador. O golpe espera 2 quadros de física, aplica dano a todos os corpos dentro do arco (`get_overlapping_bodies()`) e destrói projéteis inimigos (`get_overlapping_areas()`). Empurra pouco o inimigo, para ele continuar ao alcance.
  - **Bola de fogo / Flecha:** instancia o projétil e emite o sinal `disparou`. A fase recebe o sinal e coloca o projétil no nó `Projeteis`. Com a melhoria "Projétil extra", `_disparar_leque()` abre vários projéteis em leque.
  - Com o botão do mouse apertado, a mira vai na direção do cursor (`get_global_mouse_position()`).
- **Poder especial** (`_usar_poder`), com `match classe.poder`:
  - **Giro da Espada:** instancia `giro_espada.tscn`, uma área circular com lâminas girando; acerta cada inimigo uma vez com dano dobrado e `quebra_escudo = true`; o herói fica invencível durante o giro.
  - **Explosão Arcana:** cria 14 bolas de fogo em círculo (`Vector2.from_angle(TAU * i / n)`).
  - **Chuva de Flechas:** três leques de 7 flechas, com `await` de 0,12 s entre eles. O timer usa `create_timer(t, false)`, então **respeita a pausa**.
  - A recarga é emitida pelo sinal `poder_mudou`, que o HUD usa para encher a barrinha embaixo do ícone.
- **Esquiva** (`_esquivar`): durante 0,18 s a velocidade é fixa em 260 na direção do movimento e o herói fica invencível. A cada quadro, `_rastro()` cria uma cópia azulada do sprite que some com um `Tween`.
- **Dano:** `levar_dano(origem)` ignora o golpe se o herói estiver invencível. Senão, tira uma vida, empurra o jogador (*knockback*), treme a câmera e deixa o herói invencível por 1,2 s, piscando.
- **Câmera:** `Camera2D` filha do jogador, então ela o segue sozinha. O script `camera_jogo.gd` recebe os limites do mapa e tem a função `tremer()`.

---

## 7. Experiência e níveis

1. Quando um inimigo morre, a fase chama `_ganhar_xp(inimigo.xp)`.
2. `Global.ganhar_xp()` soma a XP e devolve **quantos níveis** o jogador subiu (pode ser mais de um de uma vez, por exemplo ao derrotar um chefão). O nível seguinte pede `6 + 6 × nível` de XP.
3. Para cada nível ganho, a fase abre a tela `subir_nivel.tscn`. Se subiu dois níveis, a segunda tela abre logo depois da primeira (fila em `_niveis_pendentes`).
4. A tela **pausa o jogo** (`get_tree().paused = true`). Ela funciona pausada porque tem `process_mode = PROCESS_MODE_ALWAYS`.
5. As melhorias ficam numa lista `MELHORIAS`. A tela filtra as que valem para a classe (por exemplo, "Lâmina longa" só para o Guerreiro), embaralha com `shuffle()` e mostra 3.
6. A melhoria escolhida altera uma variável do `Global` (`bonus_dano`, `mult_recarga`, `projeteis_extra`...). O jogador lê essas variáveis sempre que ataca, então o efeito vale na hora e continua nas próximas fases.

O menu de pausa **ignora a tecla Esc** enquanto a tela de nível está aberta, para as duas telas não brigarem pela pausa.

---

## 8. Inimigos comuns (herança)

Todos herdam de **`Inimigo`** (`scripts/inimigos/inimigo.gd`, com `class_name Inimigo`). A classe base cuida de:

- vida, pontos, XP e chance de soltar item (variáveis `@export`, editáveis no Inspetor);
- dano por contato (`AreaDano` → `get_overlapping_bodies()`);
- piscar branco ao levar dano, ser empurrado e mostrar o número do dano;
- **barra de vida** desenhada em `_draw()` com `draw_rect()`, visível por 2,5 s depois de cada golpe;
- **elite** (`tornar_elite()`): dobro de vida, 1,2× maior, 15% mais rápido, brilho dourado pulsando e uma **coroa** desenhada com `draw_colored_polygon()`;
- **aviso de ataque** (`avisar()`): um `Tween` que pisca o sprite em vermelho;
- morrer: partículas, som, sinal `derrotado`.

Cada inimigo filho só **sobrescreve** `_calcular_velocidade()` (e, se precisar, `_ao_morrer()` ou `receber_dano()`):

| Script | Lógica |
|--------|--------|
| `slime_patrulheiro.gd` | anda em `direcao` e inverte quando percorre a `distancia` ou quando `is_on_wall()` é verdadeiro |
| `slime_perseguidor.gd` | persegue dentro de `raio_visao` e desiste além de `raio_desistir`; de longe mira um ponto ao redor do jogador (`_angulo_cerco`, sorteado para cada slime), o que cria o **cerco**; com 1 de vida foge por 1,5 s |
| `slime_cuspidor.gd` | mantém distância; com visão do jogador, incha (aviso) e instancia uma gosma |
| `morcego.gd` | vai em direção ao jogador somando um seno perpendicular (zigue-zague) e volta ao ninho se o jogador estiver longe |
| `esqueleto_arqueiro.gd` | procura visão do jogador (usa o A\* se não enxerga), recua se o jogador estiver perto, mira 0,5 s e atira uma flecha |
| `fantasma.gd` | máscara de colisão 0 (atravessa tudo); a transparência (`modulate.a`) depende da distância ao jogador |
| `golem_escudeiro.gd` | máquina de estados `andar → aviso → investida`; sobrescreve `receber_dano()`: se o golpe vem da frente (produto escalar `dot` entre a direção do golpe e `_frente` > 0,35) e não quebra escudo, o dano é bloqueado |
| `slime_bomba.gd` | perto do jogador troca para a animação `piscar` e, após 0,9 s, explode: fere o jogador e os inimigos dentro do raio |
| `slime_gigante.gd` | herda do perseguidor (`extends "slime_perseguidor.gd"`); em `_ao_morrer()` cria 2 slimes roxos e os entrega à fase pelo sinal `gerou` |

### Inteligência: visão e caminho (A\*)

- **Visão:** `tem_visao(alvo)` lança um raio (`PhysicsRayQueryParameters2D`) contra as camadas mundo e água. Se o raio não bate em nada, o inimigo enxerga o alvo.
- **Caminho:** a fase monta um `AStarGrid2D` com o tamanho do mapa e marca como sólidas as células com água, decoração com colisão ou portão (`_montar_grade()`). Os portões viram células livres quando se abrem.
- `mover_para(alvo)`: se o inimigo enxerga o alvo, vai em linha reta; senão pede `fase.caminho(de, para)` (recalculado a cada 0,5 s) e segue os pontos do caminho, contornando lagos e muros.

---

## 9. Chefões (`scripts/inimigos/chefe.gd`)

Os três chefões herdam de **`Chefe`** (`class_name Chefe`). A base cuida de: acordar quando o jogador chega perto (`raio_despertar`), vida e **fúria** (metade da vida), sorteio de ataques sem repetir (`sortear_ataque(n)`), dano por contato e a morte com explosões.

Cada chefão implementa só `_atacar()` e `_movimento()`. Os ataques são escritos de forma **sequencial com `await`**, o que deixa o código parecido com uma receita:

```gdscript
1:  # PANCADA do Golem
    animacao.play("golpe")
    avisar(0.7)                       # pisca em vermelho
    if not await esperar(0.75):       # espera respeitando a pausa
        return                        # (falso = o chefe morreu nesse meio-tempo)
    onda_de_choque(110.0)
```

`esperar()` usa `create_timer(segundos, false)`, então **pausar o jogo também pausa o chefe**, e devolve `false` se o chefe morreu durante a espera, para o ataque parar na hora. Enquanto um ataque roda, `_ocupado` fica verdadeiro; ao morrer, o chefe espera o ataque terminar antes de sumir.

Utilidades da base usadas pelos três: `atirar(cena, direção)`, `onda_de_choque(raio)` (instancia `onda_choque.tscn`, um anel que cresce e fere o jogador quando a borda passa por ele) e `area_de_aviso(posição, raio, atraso)` (instancia `aviso_area.tscn`, um círculo vermelho que pisca e depois fere quem estiver dentro).

| Chefão | Ataques (`match sortear_ataque(n)`) | Fúria |
|--------|------------------------------------|-------|
| `golem_pedra.gd` | 0 arremesso de pedras · 1 pancada com onda de choque · 2 investida (fica tonto se bater na parede) | 5 pedras, 2 pancadas, investida mais rápida |
| `bruxa_pantano.gd` | 0 teletransporte (só para chão livre: `fase.ponto_livre()`) · 1 espíritos que perseguem · 2 invoca morcegos · 3 espiral de gosma | 5 espíritos, 3 morcegos, espiral dupla |
| `rei_slime.gd` | 0 rajada de anéis · 1 investida · 2 invoca slimes · 3 salto com área de aviso e onda de choque | ganha o ataque 4: **chuva de gosma** com várias áreas de aviso |

O chefe se comunica com a fase e com o HUD **só por sinais** (`ativado`, `vida_mudou`, `enfureceu`, `invocou` e `derrotado`), então ele não precisa conhecer nenhum dos dois.

---

## 10. Fases (`scripts/fases/fase.gd`)

As três fases usam **o mesmo script**. O que muda está nas variáveis exportadas: tempo limite, música, quais inimigos podem surgir, intervalo de surgimento, chance de elite, se a vitória vem pela bandeira e se a luz do jogador fica ligada.

```
Fase1 (Node2D, fase.gd)
├── Mundo            (instância do mapa com as TileMapLayers)
├── Ambiente         (CanvasModulate: escurece o pântano e o castelo)
├── Decoracoes       (tochas com PointLight2D)
├── Entidades        (Y-Sort ligado: quem está mais embaixo é desenhado na frente)
│   ├── Portoes
│   ├── Itens
│   ├── Inimigos
│   ├── Projeteis    (projéteis, efeitos e textos flutuantes)
│   ├── Saida
│   ├── Chefe
│   └── Jogador
├── PontosSpawn      (Marker2D onde surgem novos inimigos)
├── TimerSpawn
├── HUD              (CanvasLayer)
├── MenuPausa        (CanvasLayer)
└── SubirNivel       (CanvasLayer)
```

Responsabilidades do script:

1. **Conecta os sinais** de todos os itens (`coletado`) e inimigos (`derrotado`, `gerou`), inclusive os criados durante o jogo, e os do chefe.
2. **Chaves:** ao juntar 3, chama `abrir()` em todos os nós do grupo `"portoes"` e libera essas células na grade do A\*.
3. **Chefe e portal:** o portal começa desativado (`saida.desativar()`). Quando o chefe emite `derrotado`, todos os inimigos restantes morrem e o portal acende (`saida.ativar()`). Na fase 3, em vez do portal, a **bandeira** é instanciada no `PontoBandeira`.
4. **Instâncias dinâmicas:**
   - `_gerar_inimigo()`: a cada tique do `TimerSpawn`, cria um inimigo num ponto longe do jogador, às vezes como **elite**, e diminui o intervalo;
   - `_soltar_item()`: um inimigo derrotado pode deixar uma moeda ou um coração, que "pula" ao aparecer;
   - lacaios do chefe e filhotes do slime gigante chegam pelos sinais `invocou` e `gerou`.
5. **XP e níveis:** veja a seção 7.
6. **Tempo:** conta para baixo, avisa aos 30 s e causa derrota em 0.
7. **Fim:** vitória chama `Global.concluir_fase()` com um resumo; derrota chama `Global.perder()`.

> Por que `call_deferred`? Adicionar corpos físicos **durante** um sinal de colisão pode dar erro no Godot. Por isso os itens que caem, os projéteis e os inimigos novos são adicionados "no fim do quadro".

> Por que os projéteis inimigos vão para `Projeteis` e não para `Inimigos`? Porque a fase conta os filhos de `Inimigos` para limitar quantos inimigos existem ao mesmo tempo (`max_inimigos`). A função `adicionar_ao_mundo()` da classe `Inimigo` cuida disso.

---

## 11. Interface

- **HUD** (`hud.gd`): corações (até 9), **nível e barra de XP**, chaves, pontos, relógio (pisca em vermelho no final), **ícone do poder e barra de esquiva** com a recarga, mensagens, título da fase e barra de vida do chefão (com o nome dele).
- **Escolha do herói** (`selecao_classe.gd`): três cartas montadas a partir dos Resources das classes; a descrição muda quando o botão recebe foco ou o mouse passa por cima.
- **Subir de nível** (`subir_nivel.gd`): veja a seção 7.
- **Menu de pausa** (`menu_pausa.gd`): `process_mode = Sempre`, então funciona com `get_tree().paused = true`. Liga e desliga música e efeitos (salvo no disco).
- **Tema** (`recursos/tema.tres`): fonte pixel, estilos dos botões (normal, foco, hover e pressionado), painéis e barras. Todas as telas herdam esse tema.

---

## 12. Arte e áudio

- Toda a arte é **original**, em 16×16 (32×32 para os chefões), com a paleta *Endesga 32*. Os arquivos ficam em `arte/`, separados por tipo: `personagens/` (uma folha por classe, `inimigos.png`, `inimigos2.png`, `chefes.png`, `rei_slime.png`), `objetos/` (itens, `golpe.png`, `ataques.png`) e `ui/icones.png` (ícones dos poderes e da esquiva).
- Efeitos sonoros e músicas também são **originais**: sintetizados em estilo 8 bits, em `audio/sfx` e `audio/musica`. Cada fase tem uma música, e os chefões têm a deles.

---

## 13. Checklist dos requisitos

- [x] Menu inicial com Jogar, Créditos e Sair
- [x] Câmera seguindo o jogador, com limites do mundo
- [x] TileMapLayer no cenário (5 camadas por fase, também usadas na navegação A\*)
- [x] Inimigos com comportamento (9 tipos com IA + 3 chefões com vários ataques e fúria)
- [x] Itens coletáveis (moeda, chave, coração)
- [x] Instâncias dinâmicas (ataques, projéteis, ondas de choque, inimigos, elites, lacaios, drops, bandeira, efeitos)
- [x] Menu de pausa em CanvasLayer com opção de sair
- [x] Tela de final (vitória/derrota) com reinício e volta ao menu
- [x] Projeto organizado em pastas, com nós nomeados e dados das classes em Resources
