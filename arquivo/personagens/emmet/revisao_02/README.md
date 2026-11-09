# Emmet — revisão 02: ossos dos braços mais dentro da manga

Feedback recebido: «a movimentação dos braços […] está localizado muito por cima do braço […] deveria estar mais dentro do braço».

A revisão 01 foi preservada. Esta versão corrige o posicionamento real dos ossos, não apenas o traço do vídeo. Continua na etapa de revisão da articulação, sem integração no jogo.

## Vídeos

[**Descarregar o vídeo completo — 24 segundos**](https://github.com/TomasRosario1/Games-reprosit-rio/raw/refs/heads/main/arquivo/personagens/emmet/revisao_02/00_revisao_completa.mp4)

| Vídeo | O que mostra |
| --- | --- |
| [01 — Posição real, vista 360°](01_esqueleto_360.mp4) | Esquerda: corpo com textura. Direita: malha em arame com a posição real dos ossos e os braços recentrados. Só a câmara roda; não há deslocação dos ossos para a frente da pele. |
| [02 — Braços corrigidos](02_bracos.mp4) | Cotovelos (0–3 s), ombros (3–6 s) e pulsos (6–8 s), com enquadramento mais próximo. Corpo deformado e malha com ossos reais, na mesma pose. |
| [03 — Comparação dos braços](03_comparacao_bracos.mp4) | Esquerda: revisão 01 anterior. Direita: revisão 02 corrigida. Os dois modelos executam exatamente os mesmos testes e ângulos, com a mesma iluminação e textura. |

Se o GitHub não mostrar um leitor, usa **View raw / Download raw file** no MP4. Depois de descarregar e extrair o ZIP do repositório, podes abrir [ver_videos.html](ver_videos.html) no navegador, sem instalação. O leitor permite reduzir a velocidade.

## O que mudou

- Na revisão 01, alguns pivôs dos ombros e cotovelos estavam à frente da superfície da manga. Os pulsos também estavam demasiado próximos da frente da pele.
- Os pontos de rotação foram recentrados usando as interseções reais com a frente e as costas da malha em cada articulação, incluindo diferenças entre os dois lados.
- Os ombros foram baixados 4,5 cm. Braços, antebraços e pulsos foram alinhados com o volume da manga; os pesos foram ajustados ao novo encaixe.
- A vista em arame mostra a posição 3D verdadeira. As linhas da revisão 01 eram projetadas à frente da pele para se verem, o que também dificultava avaliar a profundidade.
- O formato e tamanho do corpo/mãos em repouso, a textura e os triângulos não foram alterados. Só foram revistos ossos e pesos dos braços.

## Verificação e ficheiros

- [Modelo Blender editável](emmet_articulacao_02.blend).
- [GLB articulado](emmet_articulacao_02.glb).
- [Posições dos ossos e medições da manga](relatorio.json).
- [Validação técnica e vídeos](validacao.json).

O validador confere os pivôs exportados através das matrizes de ligação do GLB, oito pontos ajustados com mais de 3 cm de margem em profundidade, vinte amostras dos eixos dos braços dentro da malha, pesos normalizados e geometria/UVs iguais à revisão 01. Isto não equivale a aprovação artística: continua a ser importante observar a forma das mangas nas flexões.

Para reproduzir na raiz do repositório:

```sh
blender -b --python arquivo/personagens/ferramentas/preparar_emmet.py -- --revision=02 --render
python3 arquivo/personagens/ferramentas/codificar_videos.py --revision=02
python3 arquivo/personagens/ferramentas/validar_arquivo.py
```

## Próximo feedback

Indica o número do vídeo e o segundo onde o encaixe ou movimento ainda não esteja correto. Permanecemos nesta etapa até reveres os braços; andar/correr, variantes e integração não foram iniciados nesta alteração.
