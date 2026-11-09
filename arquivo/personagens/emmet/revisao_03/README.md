# Emmet — revisão 03: andar e entrar nos veículos

A articulação da [revisão 02](../revisao_02/README.md) foi aprovada pelo criador. Esta etapa apresenta as animações pedidas para feedback. As posições e dimensões dos 21 ossos foram mantidas; foram afinados pesos locais na zona do assento das calças para a flexão das pernas.

## Vídeos — 720p, 24 fps

[**Descarregar a sequência completa — 24 segundos**](https://github.com/TomasRosario1/Games-reprosit-rio/raw/refs/heads/main/arquivo/personagens/emmet/revisao_03/00_animacoes_completas.mp4)

| Vídeo | O que observar |
| --- | --- |
| [01 — Andar](01_andar.mp4) | Oito segundos de deslocação real: pés apoiados alternadamente, passada, joelhos, balanço dos braços e movimento do tronco. Vista de três quartos nos primeiros quatro segundos e lateral nos últimos quatro. As linhas do chão estão fixas no mundo. |
| [02 — Entrar no carro](02_entrar_carro.mp4) | Aproximação, abertura da porta, posicionamento, baixar o corpo, colocar a primeira perna, sentar, recolher a outra perna, puxar a porta e alcançar volante/chão. Vista traseira/lateral durante a entrada e dianteira na posição final. Os vidros estão ocultos para observar o encaixe. |
| [03 — Montar a mota](03_montar_mota.mp4) | Aproximação, mão no guiador, passagem da perna por cima da parte traseira do banco, transferência do peso e posição final com pés nos apoios. Vista traseira durante a passagem da perna; dianteira no fim. A mota está apoiada num descanso visível. |

Também podes abrir os MP4 no GitHub com **View raw / Download raw file**. Se descarregares e extraíres o ZIP do repositório, abre [ver_videos.html](ver_videos.html): funciona no navegador, sem instalação nem Internet, e permite ver a 0,5x ou 0,25x.

São renderizações da malha e do esqueleto reais, com animações guardadas nos ficheiros 3D. Não são vídeos de gameplay ou movimento inventado por IA de vídeo. Os dedos continuam sem articulação individual e esta revisão não acrescenta simulação de tecido.

## Ficheiros para editar ou reutilizar

| Movimento | Blender editável | Cena GLB com a animação |
| --- | --- | --- |
| Andar | [01_andar.blend](01_andar.blend) | [01_andar.glb](01_andar.glb) |
| Entrada no carro | [02_entrar_carro.blend](02_entrar_carro.blend) | [02_entrar_carro.glb](02_entrar_carro.glb) |
| Montar a mota | [03_montar_mota.blend](03_montar_mota.blend) | [03_montar_mota.glb](03_montar_mota.glb) |

No Blender, a ação correspondente está ativa e a câmara de revisão está preparada. Usa **Numpad 0** para a vista da câmara e **Espaço** para reproduzir. Os ficheiros estão comprimidos sem perda para reduzir a transferência.

Cada GLB contém uma única animação com o nome do ficheiro, com deslocação da raiz. As cenas de entrada incluem o respetivo veículo; o carro inclui a porta animada. São cenas de revisão, não substituições prontas do controlador do jogador. Ao importar, conservar a amostragem original de **24 fps** evita uma nova conversão das poses.

## Veículos usados nesta revisão

Os modelos partiram dos veículos próprios de `scripts/vehicle.gd`, exportados diretamente do projeto. Os [originais exportados e metadados](veiculos/) estão guardados. A preparação para Blender remove apenas a extensão de visibilidade não suportada pela versão 4.3, conservando os nós que estavam ocultos.

Para a entrada fazer sentido, o carro desta revisão tem uma abertura física na porta e no habitáculo, em vez de atravessar a carroçaria fechada anterior. A porta tem painel, moldura, puxadores e dobradiça. A posição do volante foi ajustada 20 cm para o encaixe deste modelo; o pilar fica na extremidade da porta. A mota recebeu um descanso para permanecer apoiada durante a montagem. Estes ajustes estão **apenas no arquivo**; os veículos e personagens do jogo atual não foram substituídos.

## Validação

- [Validação técnica e dados dos vídeos](validacao.json).
- [Fontes Blender verificadas](fontes_validadas.json): posições dos ossos e geometria em repouso iguais às da revisão 02, UVs preservadas e pesos normalizados.
- [Contactos por fotograma](contactos.json): posições pedidas e efetivas de mãos/pés, deslocação da raiz, altura final da cabeça e contacto do assento.
- Godot 4.6.3: **603 verificações passaram**, importando os três GLB diretamente a 24 fps. Inclui caminhada com apoios horizontais estáveis, abertura/fecho real da porta e posições finais das mãos no volante/guiador e pés no interior/apoios.
- Os MP4 foram descodificados e conferidos: quatro vídeos H.264, 1280 × 720, 24 fps — três de oito segundos e a sequência completa de 24 segundos.

Os testes técnicos não substituem a avaliação visual da postura, ritmo ou deformação da roupa.

## Reproduzir

Na raiz do projeto, com Godot, Blender e FFmpeg:

```sh
godot --headless --script arquivo/personagens/ferramentas/exportar_veiculos_revisao.gd
blender -t 4 -b --python arquivo/personagens/ferramentas/animar_emmet.py -- --render
blender -t 2 -b --python arquivo/personagens/ferramentas/finalizar_fontes_emmet.py
python3 arquivo/personagens/ferramentas/codificar_animacoes_emmet.py
godot --headless --script arquivo/personagens/ferramentas/validar_animacoes_emmet.gd
python3 arquivo/personagens/ferramentas/validar_revisao03.py
```

O exportador usa um processo Blender novo por cena e só as ações relevantes, evitando misturar testes antigos com a animação pedida. Fotogramas e ficheiros temporários ficam em `/tmp/emmet-review-03`, fora do GitHub. Na nuvem, os comandos usam diretórios XDG graváveis.

## Feedback seguinte

Indica **vídeo + segundo + o que funciona ou precisa de mudar**. Exemplo: «Mota, segundo 3: levanta mais o pé ao passar sobre o banco».

Esta etapa aguarda o teu feedback sobre as animações. As variantes de cor/forma e a integração como quarta personagem continuam para depois, seguindo a ordem combinada. O jogo atual não carrega esta pasta.
