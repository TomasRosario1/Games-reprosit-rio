# Personagens originais

20 adultos low-poly (10 homens e 10 mulheres) criados proceduralmente para este projeto. Não usam modelos ou animações GTA. Malhas trianguladas no GLB, texturas urbanas originais e rig humano de 18 ossos com movimentos anatómicos cozidos nos clips. Os joelhos são resolvidos para a frente, os pés mantêm a orientação do rosto e o agachar baixa a bacia no eixo vertical. Há clips próprios de agachar parado, salto, queda e aterragem.

Regenerar: `blender -b --python tools/generate_characters.py`. `source/human_source.blend` contém o primeiro corpo e rig para edição no Blender; os restantes GLB também podem ser importados. As identidades são estudos de guarda-roupa e não determinam a personalidade dos NPCs.

Os clips são animação original por articulações, sem captura de movimento nem dados dos jogos de referência. O controlador conserva a fase da passada ao mudar de velocidade e sobe degraus baixos com folga para a cabeça.
