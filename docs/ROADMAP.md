# Plano de desenvolvimento — Álbum Visual

O projeto está a iniciar a primeira experiência jogável. As funcionalidades abaixo são objetivos por fase, não uma declaração de que já estão prontas. O código, os testes e o README da versão entregue estabelecem o que realmente foi implementado.

## 1. Primeira experiência jogável

**Percurso de referência:** telhado → rua → favor a um NPC → entrada num bar → atuação musical.

Preparar uma aplicação Godot 4 desktop em Compatibility, com um quarteirão noturno pequeno. Priorizar a sensação de explorar e descobrir música, antes de expandir combate ou cidade.

- Personagem provisória texturada e em terceira pessoa; andar, correr, agachar, saltar e câmara com colisão e recentramento.
- Telhado inicial, acesso à rua e bar reconhecível, com materiais de desgaste e iluminação noturna.
- Interação contextual e um favor simples que permita experimentar o acesso ao bar.
- Fonte de música com aproximação e afastamento suaves; comportamento de loop consistente.
- Lista de músicas e pré-escuta, seleção de dificuldade e atuação de quatro teclas.
- Público que perde e recupera entusiasmo, falha sem pagamento e pagamento apenas ao terminar com sucesso.
- Controlos de teclado e comando, morte/renascimento e persistência mínima apropriada ao percurso implementado.
- Exportação ou instruções locais para abrir no Godot de Windows.

**Recursos nesta fase:** música de teste gerada e materiais/modelos provisórios. Nenhuma destas faixas deve ser apresentada como música da banda. Não foram fornecidos os áudios ou modelos definitivos dos protagonistas.

**Critério de conclusão:** abrir o projeto, percorrer o cenário, descobrir a interação musical e completar ou falhar uma atuação com regras de dinheiro verificadas. Validar o que existe e declarar explicitamente o que ainda falta; não chamar ao protótipo «jogo completo».

## 2. Editor dentro do jogo e IA local

O editor é requisito do criador e deve ficar dentro da aplicação, acessível num modo próprio com câmara de voo. Construir uma ferramenta visual útil antes de lhe ligar o modelo de linguagem.

1. Seleção, deslocamento, rotação e escala de objetos.
2. Catálogo de peças, luzes e materiais; importação de recursos preparados.
3. Guardar/carregar o mundo editado, IDs estáveis, cópia de segurança e desfazer/refazer.
4. Painel de texto e geração de Scene Graph da seleção e vizinhança.
5. Modelo offline executado localmente; testar no computador com RX 7600 XT.
6. Ações estruturadas validadas e pré-visualização com Aplicar, Cancelar e Desfazer.
7. Ampliar operações para personagens, áreas e comportamentos. Alterações de scripts exigem teste e possibilidade de recuperação.

**Critério de conclusão:** pedir uma alteração de luz ou objeto, inspecionar a proposta, aplicar, desfazer e conservar o mundo correto após reiniciar. Editor manual deve continuar utilizável quando a IA estiver desligada. Não colocar o modelo como requisito para jogar no HP.

## 3. Afinar estética, movimento e espaços

- Definir referências comuns de Lisboa noturna, paleta, materiais e dimensões.
- Substituir recursos provisórios por GLB/GLTF, texturas PBR de desgaste e personagens finais.
- Construir os três protagonistas, seleção inicial, troca no mundo e diferenças de movimento/atuação.
- Afinar animações, transições, casaco e enquadramentos da câmara.
- Integrar músicas autorizadas da banda, mapear notas e medir sincronização.
- Reatividade real das luzes ao espectro do áudio, com limites de custo e suavização.
- Ajustar arquitetura, percursos, interiores e locais de escuta através de sessões de jogo.

**Critério de conclusão:** o quarteirão transmite a identidade do álbum, com movimento legível, som sem cortes e recursos consistentes.

## 4. Expandir a vida noturna e a progressão

Estas funcionalidades pertencem ao jogo pretendido, mas não devem ser confundidas com o primeiro percurso funcional:

- Missões de transporte, procura, recuperação e ajuda ao bar; acessos por favores, dinheiro ou objetos.
- Cinco perfis de NPCs, vocalizações e texto contextual; seguranças e polícia com variação de personalidade.
- Combate secundário e combos simples; bosses que protegem acessos.
- Bolsa de oito espaços, objeto equipado separado, efeitos temporários e recuperação de vida.
- Morte com música distorcida e funil, perda de dinheiro/objeto equipado, preservação da bolsa e ponto seguro próximo.
- Atividades musicais próprias dos protagonistas e distribuição de receitas.
- Trânsito e quatro veículos conduzíveis: bicicleta, trotinete, mota e carro; animações de entrada/saída e acidentes.
- Mais bares e áreas estilizadas de Lisboa, incluindo Pink Street e Galito.
- Persistência do progresso com início de sessão no telhado; falhas e espera de cinco minutos nas missões secundárias.

Cada expansão precisa de uma pequena situação de teste jogável e de medição de custo; a ordem interna pode mudar com o que o criador aprender ao experimentar.

## 5. Desempenho, distribuição e validação

- Medir primeiro no ASUS e depois no HP EliteBook 745 G2 real. Não extrapolar 60 FPS a partir de testes headless ou de uma máquina mais potente.
- Alvo inicial para o HP: 720p, qualidade baixa, renderizador Compatibility; 60 FPS é um objetivo por validar.
- Preparar LOD, distâncias de desenho, carregamento por zonas, luz estática e atualizações de simulação por distância.
- Testar entrada/saída de bares, múltiplas fontes musicais, trânsito e povoamento nas situações de maior carga.
- Validar teclado/rato, comando, áudio, gravação, recuperação de ficheiros e arranque sem Internet.
- Manter requisitos do editor/IA separados dos requisitos do jogo.
- Preparar uma versão Windows exportada, com créditos, licenças e indicação clara dos recursos provisórios que ainda existam.

## Verificações que devem acompanhar a implementação

| Sistema | Evidência útil |
| --- | --- |
| Movimento | Percurso real em terceira pessoa, colisões e retomada após morte. |
| Áudio espacial | Aproximar, afastar e regressar sem cortes nem reinícios indevidos. |
| Ritmo | Acertos, erros, recuperação de público, dificuldades, falha sem pagamento e pagamento único correto. |
| Progressão | Guardar, reiniciar e restaurar o progresso mantendo o ponto inicial definido. |
| Editor | Aplicar, desfazer e carregar o mesmo estado depois de reiniciar. |
| Desempenho | Medições na máquina alvo, com resolução, qualidade e cenário registados. |

Os repositórios de referência guardados no ambiente servem para estudo. A sua presença não significa que os jogos foram instalados, executados ou que o seu código está automaticamente autorizado para reutilização.
