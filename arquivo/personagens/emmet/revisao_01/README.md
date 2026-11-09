# Emmet — revisão 01 da articulação

**Etapa atual: avaliar o esqueleto e a deformação. Aguarda o teu feedback.**

Os vídeos são renderizações do modelo GLB enviado, deformado por um esqueleto real no Blender. Não são movimentos gerados por IA de imagem/vídeo. Não foi integrado no jogo e ainda não foram criadas variantes de aparência ou animações completas de andar/correr.

## Ver os vídeos

[**Vídeo completo — 32 segundos**](00_revisao_completa.mp4)

| Vídeo | Duração | O que observar |
| --- | --- | --- |
| [01 — Encaixe do esqueleto, vista 360](01_esqueleto_360.mp4) | 8 s | Frente, lado e costas; alinhamento dos ombros, anca, joelhos, tornozelos e cabeça. Neste primeiro vídeo roda a câmara, não a personagem. |
| [02 — Braços](02_bracos.mp4) | 8 s | 0–3 s: cotovelos; 3–6 s: ombros; 6–8 s: pulsos. Reparar nos volumes das mangas e no casaco. |
| [03 — Pernas](03_pernas.mp4) | 8 s | 0–4 s: perna esquerda; 4–8 s: direita. Flexão de anca, joelho e tornozelo. É um teste de articulação, não uma caminhada. |
| [04 — Tronco e cabeça](04_tronco.mp4) | 8 s | 0–3 s: cabeça/pescoço; 3–6 s: torção do tronco; 6–8 s: inclinação da coluna. |

Em cada vídeo: **esquerda = corpo deformado; direita = a mesma pose com esqueleto sobreposto**. Linhas azuis representam ossos; pontos amarelos representam articulações. As linhas são calculadas a partir dos ossos efetivos e projetadas à frente da pele para ficarem visíveis, sem alterar a posição no ecrã. Não representam ossos a sair fisicamente do corpo.

No GitHub, abre o MP4 e usa **View raw / Download raw file** se não surgir o leitor. Também podes descarregar o ZIP do repositório, extrair e abrir [ver_videos.html](ver_videos.html): o leitor funciona localmente, sem instalação ou Internet.

## Dar feedback

Indica **número do vídeo + segundo + o que funciona ou precisa de mudar**. Exemplo: «Vídeo 02, segundo 2: o cotovelo está bem, mas a manga perde demasiado volume».

Não vou tratar a presença do esqueleto como aprovação visual. O casaco é uma malha única com o corpo; contactos nas flexões e os pesos podem precisar de ajuste manual. Esta revisão não inclui dedos articulados individualmente nem física do tecido.

Depois do feedback desta etapa, preparo vídeos de locomoção (andar, correr, agachar e restantes movimentos a escolher). Depois dessa revisão, passamos às variantes de cor, altura e proporções. A integração jogável fica para a versão aprovada.

## Ficheiros de trabalho

- [Blender editável — modelo + esqueleto](emmet_articulacao_01.blend).
- [GLB articulado — candidato de revisão](emmet_articulacao_01.glb), com os três testes de articulação exportados como clips.
- [Relatório: ossos, coordenadas, pesos e limites](relatorio.json).

Preparação: altura normalizada para 1,80 m, 21 ossos, junção de vértices coincidentes mantendo UVs/triângulos, pesos limitados a quatro influências e normalizados. A textura original 256 × 256 é mantida. O original sem esqueleto continua em `../original/` e não é sobrescrito.

## Reproduzir

A partir da raiz do repositório, com Blender e FFmpeg instalados:

```sh
blender -b --python arquivo/personagens/ferramentas/preparar_emmet.py -- --render
python3 arquivo/personagens/ferramentas/codificar_videos.py
```

Validação técnica desta entrega: [validacao.json](validacao.json). Os cinco MP4 foram descodificados e conferidos: H.264, 960 × 540, 24 fps, quatro vídeos de 8 segundos e a sequência completa de 32 segundos. A presença de movimento e a validade dos pesos não substituem a tua aprovação visual.

Verificar a integridade dos arquivos e do rig:

```sh
python3 arquivo/personagens/ferramentas/validar_arquivo.py
```

Os fotogramas temporários ficam em `/tmp/emmet-review/frames`, fora do repositório. As ferramentas usam Blender 4.3.2 nesta revisão; não são dependências do jogo.
