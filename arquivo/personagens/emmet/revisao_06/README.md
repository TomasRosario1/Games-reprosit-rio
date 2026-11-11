# Emmet — revisão 06: mota e bicicleta

Esta revisão responde ao feedback sobre a ordem da pega e a passagem da perna. **O carro da revisão 05 e a trotinete da revisão 04 ficam preservados.** A articulação aprovada da revisão 02, a textura e o modelo em repouso também se mantêm.

## Ver os vídeos

- **[Mota — 8 segundos](01_mota.mp4)**
- **[Bicicleta — 8 segundos](02_bicicleta.mp4)**
- [Quatro veículos — 32 segundos](00_quatro_veiculos.mp4): carro, mota, bicicleta e trotinete, por esta ordem.

Com o projeto descarregado, abre [ver_videos.html](ver_videos.html) no navegador. Permite ver cada vídeo a velocidade normal, metade ou um quarto. No GitHub, abre o MP4 e usa **View raw / Download** caso o leitor não apareça. É necessário estar ligado à conta com acesso a este repositório privado.

## O que rever

1. A personagem alcança o guiador **primeiro com a mão esquerda** e fecha os dedos.
2. Só depois inclina o veículo para o seu lado, mantendo a pega. A mão direita vem ajudar posteriormente.
3. Transfere o apoio, dobra o joelho e faz o pé passar por cima, considerando o volume do veículo.
4. Desce para os apoios e endireita o veículo.

A câmara é contínua e fixa durante cada montagem. Os vídeos mostram o modelo articulado, não imagens interpoladas por IA. As animações continuam no arquivo para feedback visual, **sem integração no jogo atual**.

## Ficheiros editáveis

| Veículo | Blender | GLB com animação |
| --- | --- | --- |
| Mota, nova montagem | [01_mota.blend](01_mota.blend) | [01_mota.glb](01_mota.glb) |
| Bicicleta, nova montagem | [02_bicicleta.blend](02_bicicleta.blend) | [02_bicicleta.glb](02_bicicleta.glb) |
| Carro, preservado | [Revisão 05](../revisao_05/01_carro.blend) | [GLB preservado](../revisao_05/01_carro.glb) |
| Trotinete, preservada | [Revisão 04](../revisao_04/05_subir_trotinete.blend) | [GLB preservado](../revisao_04/05_subir_trotinete.glb) |

[veiculos.json](veiculos.json) reúne os quatro caminhos. Os modelos de veículos são os próprios do projeto, usados nas revisões anteriores.

## Verificação e reprodução

Os controlos de mão e pés são comparados com a animação importada no Godot 4 Compatibility. O percurso do joelho é ajustado em torno da geometria do veículo; as calças largas têm correções de pose exportadas como morphs, sem modificar o modelo em repouso. A pega dos dedos também é um morph. As verificações geométricas cobrem as superfícies das duas pernas contra as peças visíveis do veículo, excluindo o descanso. Não constituem uma aprovação artística de realismo.

- [Resultados completos](validacao.json), [importação e contactos no Godot](validacao_godot.json) e [integridade dos ficheiros Blender](fontes_validadas.json).
- [Contactos por frame](contactos.json), [correções da roupa](roupa.json) e percurso do joelho: [mota](01_mota_joelho.json), [bicicleta](02_bicicleta_joelho.json).
- Os vídeos novos têm 192 frames cada, em H.264, 1280 × 720, 24 fps. A sequência conjunta preserva os frames descodificados do carro e da trotinete.

Na raiz do projeto, com Blender, Godot, Python e FFmpeg disponíveis:

```sh
blender -t 4 -b --python-exit-code 1 --python arquivo/personagens/ferramentas/montagem_esquerda.py -- --render
python arquivo/personagens/ferramentas/codificar_revisao06.py
blender -t 1 -b --python-exit-code 1 --python arquivo/personagens/ferramentas/validar_fontes_revisao06.py
godot --headless --rendering-method gl_compatibility --path . --script arquivo/personagens/ferramentas/validar_revisao06.gd
python arquivo/personagens/ferramentas/validar_arquivo_revisao06.py
```

Em Linux sem pasta pessoal gravável, define diretórios `XDG_DATA_HOME`, `XDG_CONFIG_HOME` e `XDG_CACHE_HOME` em `/tmp` antes de abrir o Godot. Estas ferramentas só são necessárias para refazer a revisão; não são instalações necessárias para ver os vídeos ou jogar.
