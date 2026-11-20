# CHANGELOG — Projeto Isabela 3D

## [2026-11-19 22:44] Remoção Total de Fumaça/Neblina, Conectividade WFC 100% (3 Paredes → Arco/Porta) & Correção de Clipping em Paredes
- **Backups criados**: `.backups/*.20261119_223202.bak` (`biome_weather_vfx.gd`, `day_night_cycle.gd`, `settings_manager.gd`, `playable_arena.tscn`, `game_balance.json`, `wfc_solver.gd`, `biome_arena_builder.gd`, `arena_props.gd`, `player_isabela.tscn`, `player_combat_helper.gd`, `player_camera_rig.gd`, `test_wfc_and_biomes.gd`, `test_collision_and_spawns.gd`, `biome_atmospheric_particle.gdshader`) e `.backups/CHANGELOG.md.*.bak`.
- **1. Remoção completa de fumaça e neblina ([biome_weather_vfx.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_weather_vfx.gd), [day_night_cycle.gd](file:///D:/Godot/isabela_scene_test/scripts/game/day_night_cycle.gd), [settings_manager.gd](file:///D:/Godot/isabela_scene_test/scripts/game/settings_manager.gd), [playable_arena.tscn](file:///D:/Godot/isabela_scene_test/scenes/game/playable_arena.tscn), [game_balance.json](file:///D:/Godot/isabela_scene_test/data/game_balance.json))**:
  - Removidos `shaders/biome_atmospheric_particle.gdshader` (+ `.uid`), `_spawn_cloud_layer()`, `coast_mist` e nuvens de poeira/neblina/fumaça/vapor em todos os biomas; mantidos apenas micro-efeitos nítidos (`sandstorm`, `blizzard`, `embers`, `ship_sparks`).
  - Desabilitados `fog_enabled` e `volumetric_fog_enabled` na cena, nos 5 perfis de `data/game_balance.json` (`fog_density = 0.0`, `volumetric_fog_density = 0.0`), em `DayNightCycle` e em todos os níveis de qualidade em `SettingsManager`.
- **2. Conectividade WFC & Regra "3 Paredes → 4ª Porta/Arco" ([game_balance.json](file:///D:/Godot/isabela_scene_test/data/game_balance.json), [wfc_solver.gd](file:///D:/Godot/isabela_scene_test/scripts/game/wfc_solver.gd))**:
  - Alterados os sockets de `TILE_Arch` de `["open","open","open","open"]` para `["open","wall","open","wall"]` (`weight = 1.5`) para conectar diretamente nas linhas de muro.
  - Adicionado pré-colapso circular de margem externa em `_run_once()` (`n >= 9`, `dist > center - 0.6`), `ensure_connectivity_and_doors()` (Pass 1 BFS de conectividade total convertendo muros separadores em `TILE_Arch` ou abrindo ciclos puros de quinas; Pass 2 convertendo recintos com 3 paredes em `TILE_Arch` e limpando `TILE_Pillar`/`TILE_CoverLow` na frente de qualquer entrada de arco) e `validate_connectivity()`.
- **3. Fim do clipping parcial em paredes e câmera ([biome_arena_builder.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_arena_builder.gd), [arena_props.gd](file:///D:/Godot/isabela_scene_test/scripts/game/arena_props.gd), [player_isabela.tscn](file:///D:/Godot/isabela_scene_test/scenes/game/player_isabela.tscn), [player_combat_helper.gd](file:///D:/Godot/isabela_scene_test/scripts/game/player_combat_helper.gd), [player_camera_rig.gd](file:///D:/Godot/isabela_scene_test/scripts/game/player_camera_rig.gd))**:
  - `BiomeArenaBuilder._add_tile_collision()` agora dimensiona os colisores a partir da `AABB` real do `.glb` de cada bioma (cobrindo paredes grossas do `CryoGlacier`, pilares do `VolcanicCaldera` e torres centrais de `TILE_WallCorner`, preservando o quadrante SW livre e vão de `2.64 m` em `TILE_Arch`).
  - `ArenaProps` agora gera `StaticBody3D` + `BoxShape3D` para todos os `SM_CoastRockCluster`, ajusta barreiras para `0.86 m` e `SM_CoastPylon` para raio `0.98 m`.
  - Raio da cápsula do jogador ampliado de `0.32 m` para `0.44 m` (`safe_margin = 0.04`), e `SpringArm3D` em TPS equipado com `SphereShape3D` (`radius = 0.24`, `collision_mask = 1`, `margin = 0.12`).
- **Testes (`tests/test_trilha_a_audio_and_destruction.gd`)**: forçado `_swap_biome_now("desert_coast", ...)` em `_test_arena_props_and_scifi_mood()` para validar `ArenaProps` e céu Crepúsculo de forma determinística (`3/3` PASS, `21/21` suítes locais aprovadas).
- **Verificação observada ([test_wfc_and_biomes.gd](file:///D:/Godot/isabela_scene_test/tests/test_wfc_and_biomes.gd), [test_collision_and_spawns.gd](file:///D:/Godot/isabela_scene_test/tests/test_collision_and_spawns.gd))**:
  - `LINE_GUARD_OK` (`wfc_solver.gd = 293` L, `biome_arena_builder.gd = 281` L, `biome_weather_vfx.gd = 160` L, `arena_props.gd = 261` L, `day_night_cycle.gd = 189` L).
  - `5/5` suítes headless PASS (`test_wfc_and_biomes` cobrindo 100 seeds WFC + sala fechada 4 paredes + zero fog, `test_collision_and_spawns` cobrindo AABBs reais dos 4 biomas WFC + rochas da costa + física `move_and_slide` contra parede de `CryoGlacier`, `test_day_night_cycle`, `test_playable_arena_e2e`, `test_menus_and_settings`).
  - Soak test `1920x1080` `Vulkan Forward+` (Ultra, 5 biomas + cutscene + 15 tiros/explosões por bioma): `MAX_AVG_MS=4.86`, `MAX_PEAK_MS=8.31`, `CUTSCENE_RELOCATED=true`, `SOAK_EXIT=0`, `NEW_NVLDDMKM_153=0`, [godot.log](file:///C:/Users/thiag/AppData/Roaming/Godot/app_userdata/Isabela%20Scene%20Test/logs/godot.log) limpo e `5/5` capturas `stable_*.png` inspecionadas sem fumaça nem neblina.

## [2026-11-19 22:13] Correção do Crash Vulkan TDR (`nvlddmkm` 153 / `VkResult -4` / `nvoglv64.dll`) & Spam de `Basis` em `FPS_Arms`
- **Diagnóstico verificado (Event Viewer + `godot.log`)**:
  - Crash nativo (`22:00:29`, `0xc0000005` em `nvoglv64.dll+eaab20`) precedido por eventos `nvlddmkm` Event ID `153` (`22:00:26` e `22:00:29`) e `VK_ERROR_DEVICE_LOST` (`Couldn't wait for Vulkan fence (VkResult error -4)`) na RTX 3060.
  - Log completo continha `100` erros repetidos de `Basis ... must be normalized in order to be casted to a Quaternion` vindos de `_play_clip` em [fps_viewmodel.gd](file:///D:/Godot/isabela_scene_test/scripts/game/fps_viewmodel.gd).
- **Backups criados**: `.backups/*.20261119_220807.bak` (`biome_atmospheric_particle.gdshader`, `shallow_mirror_water.gdshader`, `biome_lava_sea.gdshader`, `biome_obsidian_floor.gdshader`, `biome_volcano_cone.gdshader`, `biome_weather_vfx.gd`, `biome_arena_builder.gd`, `day_night_cycle.gd`, `settings_manager.gd`, `weapon_pool_helper.gd`, `fps_viewmodel.gd`, `weapon_vfx.gd`, `droid_destruction_vfx.gd`) e `.backups/CHANGELOG.md.20261119_221335.bak`.
- **Hipótese falseável**: reduzir overdraw/ALU nos shaders atmosféricos e de superfície, eliminar reescrita por frame de skybox/volumetric fog e higienizar a rest pose degenerada de `ThumbDistal` zera os erros de console (`Basis`), mantém `AVG_MS <= 10 ms` nos 5 biomas em `1920x1080` `Vulkan Forward+` Ultra e elimina novos eventos `nvlddmkm` Event ID `153`.
- **Correções aplicadas**:
  - **Partículas atmosféricas ([biome_atmospheric_particle.gdshader](file:///D:/Godot/isabela_scene_test/shaders/biome_atmospheric_particle.gdshader), [biome_weather_vfx.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_weather_vfx.gd))**: trocado `depth_tex` para `repeat_disable, filter_nearest`, guardados `pow(max(ridge, 0.0001), ...)` e faixa de profundidade (`raw_d > 0.00002 && raw_d < 0.99999`), substituído o FBM procedural por 3 amostragens em textura seamless 256×256 gerada uma única vez com `FastNoiseLite`, fixados `fixed_fps = 30` / `fract_delta = true` / `preprocess <= 1.4s` nos `GPUParticles3D` e balanceadas contagens/tamanhos para reduzir overdraw preservando densidade visual; [biome_arena_builder.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_arena_builder.gd) agora oculta `_runtime_root` e zera `emitting = false` antes de `queue_free()`.
  - **Otimização ALU dos shaders de superfície ([shallow_mirror_water.gdshader](file:///D:/Godot/isabela_scene_test/shaders/shallow_mirror_water.gdshader), [biome_lava_sea.gdshader](file:///D:/Godot/isabela_scene_test/shaders/biome_lava_sea.gdshader), [biome_obsidian_floor.gdshader](file:///D:/Godot/isabela_scene_test/shaders/biome_obsidian_floor.gdshader), [biome_volcano_cone.gdshader](file:///D:/Godot/isabela_scene_test/shaders/biome_volcano_cone.gdshader))**: `domain warp` calculado 1× por fragmento com diferenças avançadas de 3 taps + `pow()` protegido na água; crosta *pahoehoe* em passagem única com normal analítico na lava; Voronoi `F2-F1` de passagem única + hash aritmético sem `sin()` no piso de obsidiana; FBM 3 oitavas no cone vulcânico.
  - **Ciclo Dia/Noite, Qualidade e Luzes Transientes ([day_night_cycle.gd](file:///D:/Godot/isabela_scene_test/scripts/game/day_night_cycle.gd), [settings_manager.gd](file:///D:/Godot/isabela_scene_test/scripts/game/settings_manager.gd), [weapon_vfx.gd](file:///D:/Godot/isabela_scene_test/scripts/game/weapon_vfx.gd), [droid_destruction_vfx.gd](file:///D:/Godot/isabela_scene_test/scripts/game/droid_destruction_vfx.gd))**: removido `preload()` por frame, reduzida atualização do `_apply_lighting()` para `0.15s`, atualizados parâmetros de névoa volumétrica apenas sob dirty-flag (`q >= 2`, alcance `64–84 m`, `gi_inject = 0.0`, reprojeção temporal ligada), `ssr_max_steps` ajustado para `32`/`16` e zerado `light_volumetric_fog_energy` em flashes de tiro e explosões.
  - **Rest pose & one-shots de `FPS_Arms.glb` ([weapon_pool_helper.gd](file:///D:/Godot/isabela_scene_test/scripts/game/weapon_pool_helper.gd), [fps_viewmodel.gd](file:///D:/Godot/isabela_scene_test/scripts/game/fps_viewmodel.gd))**: `sanitize_fps_animations()` agora normaliza bases/escalas zeradas em `Skeleton3D` (`LeftThumbDistal`/`RightThumbDistal` `[1, 0, 1]`) e filhos `Node3D`, e `_play_clip()` usa `_anim_player.stop(true)` (`keep_state`).
- **Verificação observada**:
  - `LINE_GUARD_OK` em todos os `52` scripts de `scripts/game/*.gd` (`max = 299` L).
  - `5/5` suítes headless PASS sem nenhum erro de `Basis`: `test_wfc_and_biomes`, `test_day_night_cycle`, `test_collision_and_spawns`, `test_playable_arena_e2e`, `test_menus_and_settings`.
  - Soak test real `1920x1080` `Vulkan Forward+` (Ultra, `vsync = false`, RTX 3060, 5 biomas + 15 tiros/reloads + explosões + cutscene completa `CUTSCENE_RELOCATED=true`): `desert_coast` `AVG=3.70ms`/`MAX=5.93ms`, `sand_dunes_pyramid` `AVG=3.90ms`/`MAX=5.24ms`, `mothership_interior` `AVG=6.27ms`/`MAX=8.50ms`, `cryo_glacier` `AVG=5.17ms`/`MAX=6.98ms`, `volcanic_caldera` `AVG=5.10ms`/`MAX=6.79ms`; `SOAK_EXIT=0`, `NEW_NVLDDMKM_153=0`, `godot.log` sem nenhum erro e `5/5` capturas `stable_*.png` validadas.

## [2026-11-19 21:58] Passe Orgânico e Fotorrealista: Água, Poeira, Neblina no Gelo, Fumaça e Lava
- **Backups criados**: `.backups/*.20261119_214624.bak` (`shallow_mirror_water.gdshader`, `biome_obsidian_floor.gdshader`, `biome_lava_sea.gdshader`, `biome_volcano_cone.gdshader`, `biome_weather_vfx.gd`, `biome_arena_builder.gd`, `biome_material_library.gd`, `day_night_cycle.gd`, `settings_manager.gd`, `game_balance.json`, `CHANGELOG.md`).
- **Água espelhada orgânica ([shallow_mirror_water.gdshader](file:///D:/Godot/isabela_scene_test/shaders/shallow_mirror_water.gdshader))**: substituída a soma fixa de 3 senos por campo de altura FBM 4 oitavas com *domain warping* rotacionado, rajadas macro (`gust`), ondulação sutil de vértice (`swell_height`) e cáusticas subaquáticas preservando opacidade para reflexos SSR e os 4 parâmetros de ondulação nos pés.
- **Partículas atmosféricas suaves ([biome_atmospheric_particle.gdshader](file:///D:/Godot/isabela_scene_test/shaders/biome_atmospheric_particle.gdshader), [biome_weather_vfx.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_weather_vfx.gd), [biome_arena_builder.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_arena_builder.gd#L79-L82))**:
  - Criado shader espacial billboard FBM 4 oitavas com fade por profundidade reversa (`hint_depth_texture`), `fog_disabled`, fade de proximidade de câmera e sombreamento bifásico (`color_bottom` / `color_top`);
  - Adicionados turbulência, `CurveTexture` de opacidade/escala e `DISTANCE_FADE_PIXEL_ALPHA` nos destaques (`sandstorm`, `blizzard`, `embers`, `ship_sparks` e nova bruma costeira `coast_mist` na `desert_coast`).
- **Lava vulcânica orgânica ([biome_obsidian_floor.gdshader](file:///D:/Godot/isabela_scene_test/shaders/biome_obsidian_floor.gdshader), [biome_lava_sea.gdshader](file:///D:/Godot/isabela_scene_test/shaders/biome_lava_sea.gdshader), [biome_volcano_cone.gdshader](file:///D:/Godot/isabela_scene_test/shaders/biome_volcano_cone.gdshader), [biome_material_library.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_material_library.gd#L212-L216))**: duplo *domain warping* + constrição (`pinch`) + convecção + chanfros no piso de obsidiana; crosta *pahoehoe* em 3 estágios com normal map no mar de lava; canais sinuosos por contorno FBM na encosta do vulcão.
- **Névoa volumétrica por bioma ([game_balance.json](file:///D:/Godot/isabela_scene_test/data/game_balance.json), [day_night_cycle.gd](file:///D:/Godot/isabela_scene_test/scripts/game/day_night_cycle.gd), [settings_manager.gd](file:///D:/Godot/isabela_scene_test/scripts/game/settings_manager.gd))**: configurada por bioma em runtime (`volumetric_fog_enabled`) e desabilitada no preset `Baixo` (`graphics_quality == 0`).
- **Verificação final**: `LINE_GUARD_OK`, `5/5` suítes (`test_wfc_and_biomes`, `test_day_night_cycle`, `test_collision_and_spawns`, `test_playable_arena_e2e`, `test_menus_and_settings`) passando e 3 passes de inspeção visual em `Vulkan Forward+` na RTX 3060.

## [2026-11-19 20:55] Atualização de Documentação para Handoff (`GEMINI.md` & `README.md`)
- **Backups criados**: `.backups/GEMINI.md.20261119_205413.bak`, `.backups/README.md.20261119_205503.bak` e `.backups/CHANGELOG.md.*.bak`.
- **[GEMINI.md](file:///D:/Godot/isabela_scene_test/GEMINI.md)**: atualizado mapa para `52` scripts (`scripts/game/*.gd`), `21` suítes de teste (`tests/test_*.gd`), `11` shaders (`shaders/*.gdshader`), novos diretórios (`ENV_{CoastProps,SandPyramid,MothershipInterior,CryoGlacier,VolcanicCaldera}`, `assets/textures/pbr/`, `blend_sources/gen_biome_kits.py`), resumo técnico dos 5 biomas WFC + correções de colisão e próximos passos planejados.
- **[README.md](file:///D:/Godot/isabela_scene_test/README.md)**: atualizada visão geral multi-bioma, comando de inicialização (`F5` / `F6`) e runner das `21` suítes headless.

## [2026-11-19 20:43] Correção Crítica de Colisões, Paredes Invisíveis, Spawns em Obstáculos & Elevadores Anti-Esmagamento
- **Backups criados**: `.backups/*.20261119_203541.bak` (`arena_props.gd`, `arena_elevators.gd`, `wfc_solver.gd`, `biome_arena_builder.gd`, `biome_manager.gd`, `wave_spawner.gd`, `test_wfc_and_biomes.gd`, `test_arena_elevators.gd`) e `.backups/CHANGELOG.md.20261119_204314.bak`.
- **Fim das paredes invisíveis (`19` colisores fantasmas eliminados)**:
  - [arena_props.gd](file:///D:/Godot/isabela_scene_test/scripts/game/arena_props.gd#L44-L53): adicionado `set_props_active(active: bool)` que desabilita todos os `CollisionShape3D` e zera `collision_layer` de barreiras, caixas, pylons e barris de `ArenaProps` quando ocultos nos biomas WFC (restaurando a layer original ao voltar para `desert_coast`).
  - [biome_manager.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_manager.gd#L186-L205): `_set_desert_nodes_visible()` agora chama `props.set_props_active(vis)` e desabilita eventuais colisores em `SM_DesertDunes`/`SM_ShoreRocks`; adicionado `_relocate_trapped_entities()` para realocar inimigos/caixas caso surjam em célula ocupada na troca de bioma.
  - [biome_arena_builder.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_arena_builder.gd#L186-L202): substituído o colisor quadrado de `TILE_WallCorner` (`3.4×3.4`) por **2 colisores exatos em L** (braço Leste `+X` e braço Norte `-Z`), adicionado lintel superior em `TILE_Arch` e trocados os footprints circulares aproximados por **OBBs rotacionados exatos (`_obstacle_obbs`)**.
  - [wfc_solver.gd](file:///D:/Godot/isabela_scene_test/scripts/game/wfc_solver.gd#L11-L135): adicionado `forced_open_cells` para pré-colapsar como `TILE_Open` todas as células ao redor das 4 plataformas móveis de `ArenaElevators`.
- **Zero inimigos spawnando dentro do cenário**:
  - [wave_spawner.gd](file:///D:/Godot/isabela_scene_test/scripts/game/wave_spawner.gd#L101-L265): `_is_spot_clear()` agora valida OBBs do bioma + footprints dos 4 elevadores + consulta real de física 3D (`PhysicsShapeQueryParameters3D` com `CylinderShape3D` contra `collision_mask = 1`); removidos fallbacks cegos em `pick_ring_spawn_position()`, `_spawn_reinforcement_at()` e drops de caixas.
- **Proteção anti-aprisionamento sob plataformas móveis**:
  - [arena_elevators.gd](file:///D:/Godot/isabela_scene_test/scripts/game/arena_elevators.gd#L116-L185): `_protect_entities_under_platform()` empurra lateralmente jogadores/inimigos antes do contato quando a plataforma desce (`clearance <= 2.35 m`) e garante ejeção imediata para a borda livre (ou elevação limpa para o topo do deck `new_y + 0.12`) se `clearance <= 1.88 m`.
- **Regressão TDD ([test_collision_and_spawns.gd](file:///D:/Godot/isabela_scene_test/tests/test_collision_and_spawns.gd))**: inicialmente RED (`19` `CollisionShape3D` fantasmas + `7/50` spawns bloqueados); após as correções → `LINE_GUARD_OK` e `5/5` suítes PASS (`test_collision_and_spawns`, `test_arena_elevators`, `test_wfc_and_biomes`, `test_playable_arena_e2e`, `test_spawner_projectiles_pickups`).

## [2026-11-19 20:15] Reconstrução Fotorrealista AAA dos 5 Biomas (Poly Haven PBR + 10 Shaders GLSL + Primitivas Próprias)
- **Backups criados**: `.backups/*.20261119_195234.bak` (`gen_biome_kits.py`, `biome_arena_builder.gd`, `biome_weather_vfx.gd`, `biome_manager.gd`, `day_night_cycle.gd`, `arena_props.gd`, `game_balance.json`) e `.backups/CHANGELOG.md.20261119_201509.bak`.
- **Texturas PBR Fotogramétricas CC0 (`assets/textures/pbr/`)**: adicionados 7 packs 1K (`Diffuse`, `nor_gl`, `Rough`) da Poly Haven (`coast_sand_01`, `large_sandstone_blocks_01`, `sandstone_cracks`, `metal_plate_02`, `blue_metal_plate`, `snow_02`, `dark_rock_02`), gerenciados em cache compartilhado por [biome_material_library.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_material_library.gd).
- **10 Shaders GLSL `Forward+` (`shaders/biome_*.gdshader`)**: `biome_sand_floor`, `biome_desert_dunes`, `biome_mothership_deck`, `biome_space_viewport`, `biome_ice_floor`, `biome_glacier_mountain`, `biome_aurora`, `biome_obsidian_floor`, `biome_lava_sea`, `biome_volcano_cone`.
- **Primitivas 3D Próprias por Bioma ([gen_biome_kits.py](file:///D:/Godot/isabela_scene_test/blend_sources/gen_biome_kits.py))**:
  - Novos props PBR para Bioma 1 em `assets/ENV_CoastProps/` (`SM_CoastBarrier`, `SM_CoastCrate`, `SM_CoastPylon`, `SM_CoastRockCluster`) integrados em [arena_props.gd](file:///D:/Godot/isabela_scene_test/scripts/game/arena_props.gd);
  - Malhas esculpidas de alta resolução com box-UV e normais verificadas para `ENV_SandPyramid` (piso sólido de lajes/areia, 3 pirâmides, mesas, obeliscos, portais), `ENV_MothershipInterior` (domo 16 baías, janelas estelares, cabos em catenária, gaiola do reator), `ENV_CryoGlacier` (picos alpinos multi-oitava, torres de gelo, Aurora Boreal, cristais ciano) e `ENV_VolcanicCaldera` (estratovulcão com cratera côncava, colunas hexagonais de basalto, arcos curvos com magma).
- **Atmosfera, Iluminação & Clima ([day_night_cycle.gd](file:///D:/Godot/isabela_scene_test/scripts/game/day_night_cycle.gd), [biome_arena_builder.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_arena_builder.gd), [biome_weather_vfx.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_weather_vfx.gd), [biome_manager.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_manager.gd), [game_balance.json](file:///D:/Godot/isabela_scene_test/data/game_balance.json))**: perfis de iluminação + `SSAO` + `indoor_mode`, uplights na Nave-Mãe, partículas suaves radiais em 2–3 camadas (incluindo pluma de erupção na cratera do vulcão) e reposicionamento limpo da `SM_Ship` por bioma.
- **Verificação**: `LINE_GUARD_OK`, `test_wfc_and_biomes.gd` (`PASS`), `test_day_night_cycle.gd` (`PASS`), `19/20` testes da suíte passando (`test_v2_camera_anims_fps.gd` falha pré-existente de `SpringBoneSimulator3D`), e 3 passes de inspeção visual `Forward+` nos 5 biomas.

## [2026-11-19 19:27] Reconstrução AAA dos 5 Biomas Distintos (Horizonte 3D, Pisos Únicos & VFX Climáticos)
- **Backups criados**: `.backups/*.20261119_192150.bak` e `.backups/CHANGELOG.md.20261119_192708.bak`.
- **Substituição de kits genéricos por 4 mundos arquitetonicamente distintos ([gen_biome_kits.py](file:///D:/Godot/isabela_scene_test/blend_sources/gen_biome_kits.py))**:
  - Removidas as pastas genéricas anteriores (`assets/ENV_OrbitalFoundry`, `assets/ENV_CryoRuins`, `assets/ENV_CyberMegacity`);
  - Gerados `BACKDROP.glb`, `FLOOR.glb` e 6 tiles WFC temáticos por bioma em `assets/ENV_SandPyramid/` (dunas + 3 pirâmides + obeliscos + ruínas de arenito), `assets/ENV_MothershipInterior/` (hangar circular fechado de 16 baías + reator central suspenso + dutos ciano + consoles/tanques de plasma), `assets/ENV_CryoGlacier/` (cordilheira glacial + agulhas de gelo + cristais ciano) e `assets/ENV_VolcanicCaldera/` (mar de lava + cone vulcânico + obsidiana com veios de magma + pilares de basalto).
- **Clima por Bioma ([biome_weather_vfx.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_weather_vfx.gd))**: adicionado módulo `GPUParticles3D` com `sandstorm`, `ship_sparks`, `blizzard` e `embers`, instanciado automaticamente por [biome_arena_builder.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_arena_builder.gd).
- **Configuração e Transição ([data/game_balance.json](file:///D:/Godot/isabela_scene_test/data/game_balance.json), [biome_manager.gd](file:///D:/Godot/isabela_scene_test/scripts/game/biome_manager.gd))**: atualizados os 5 biomas para `desert_coast`, `sand_dunes_pyramid`, `mothership_interior`, `cryo_glacier` e `volcanic_caldera`, com suporte a `hide_outer_ship` no hangar interno.
- **Verificação**: `tests/test_wfc_and_biomes.gd` (`ALL_TESTS_PASSED`), Line Guard (`LINE_GUARD_OK`, `0` scripts `>= 300` linhas) e 4 capturas `Forward+` inspecionadas no motor.

## [2026-11-19 19:11] Sistema Procedural WFC (Blender + Godot), 5 Biomas Aleatórios & Cutscene de Raio Trator (`SM_Ship`)
- **Backups criados**: `.backups/*.20261119_190427.bak` para `data/game_balance.json`, `scripts/game/{arena_coordinator,day_night_cycle,procedural_sfx,audio_manager}.gd` e `CHANGELOG.md`.
- **Kits Modulares 3D no Blender (`blend_sources/gen_biome_kits.py`)**: gerados `24` tiles `.glb` (`6 m × 6 m`, `TILE_{Open,CoverLow,Pillar,WallStraight,WallCorner,Arch}`) para `assets/ENV_{OrbitalFoundry,CryoRuins,CyberMegacity,VolcanicCaldera}/`.
- **Motor WFC & Biomas (`scripts/game/{wfc_solver,biome_arena_builder,biome_manager}.gd`)**:
  - `WFCSolver` resolve grade `11×11` com sockets `(N, E, S, W)`, rotações e zona central `3×3` livre de obstáculos;
  - `BiomeArenaBuilder` instancia tiles em `MultiMeshInstance3D` (1 draw call por tipo) + `StaticBody3D` + barris explosivos e alimenta `is_position_clear()`;
  - `BiomeManager` sorteia sequência aleatória sem repetição consecutiva entre os **5 biomas** (`desert_coast`, `orbital_foundry`, `cryo_ruins`, `cyber_megacity`, `volcanic_caldera`) desde a Onda 1 e troca a cada `5` ondas;
  - `DayNightCycle.set_biome_palette()` mescla atmosfera do bioma com o ciclo 24h (`1 min = 2h`).
- **Cutscene Raio Trator (`scripts/game/ship_tractor_cutscene.gd` & `procedural_sfx.gd`)**: `SM_Ship` desloca-se sobre a jogadora, dispara feixe volumétrico + 4 anéis ascendentes + SFX `"tractor_beam"`, levita, faz o swap procedural da arena e reposiciona a jogadora em `(0, 0.12, 0)`.
- **Testes (`tests/test_wfc_and_biomes.gd`)**: valida 5 biomas, WFC determinístico, sockets, spawn central livre, sequência aleatória sem repetição e SFX `"tractor_beam"`.

## [2026-11-17 16:07] Trilha 3 (Pontos 1, 3, 4) & Correção do Escudo Azul do White Reaper
- **Backups criados**: `.backups/*.20261117_160359.bak` para `SK_Boss_Reaper.glb`, `{boss_visuals_helper,boss_sentinel,player_animator,player_skin_helper}.gd`, `test_trilha_3_boss_skins_radar.gd` e `CHANGELOG.md`.
- **Animações Exclusivas no Blender ([SK_Boss_Reaper.glb](file:///D:/Godot/isabela_scene_test/assets/SK_Boss_Reaper/SK_Boss_Reaper.glb))**: adicionadas `Guard_Stance`, `Sword_Slam`, `Stagger_Core` e `Enrage_Roar` via NLA tracks em `ReaperArmature`, ligadas em [boss_visuals_helper.gd](file:///D:/Godot/isabela_scene_test/scripts/game/boss_visuals_helper.gd) e `trigger_enrage_roar()` em [boss_sentinel.gd](file:///D:/Godot/isabela_scene_test/scripts/game/boss_sentinel.gd).
- **Correção do Retângulo Azulado & VFX Shadow Blink**: substituído o `BoxMesh` azul de guarda (`boss_visuals_helper.gd`) por um `TorusMesh` energético circular (`Color(1.0, 0.38, 0.14, 0.42)`), e adicionado `spawn_blink_vfx()` âmbar na origem e destino do teleporte `Shadow Blink` do Anubis Phantom.
- **Skin Jogável de Boss ([player_animator.gd](file:///D:/Godot/isabela_scene_test/scripts/game/player_animator.gd), `290`L & [player_skin_helper.gd](file:///D:/Godot/isabela_scene_test/scripts/game/player_skin_helper.gd))**: suporte genérico a `Skeleton3D` sem `Armature_Isabela`, fallback de osso da arma (`RightHand` → `Forearm.R`), normalização de altura (`1.72 m`), preservação das texturas PBR do Reaper e driver `tick_boss_skin_anim()`.
- **Testes & Local Swarm Bridge**: `delegate_small_tasks` tentado no Ollama (`qwen2.5:7b`, fallback em nuvem por timeout `45s`); [test_trilha_3_boss_skins_radar.gd](file:///D:/Godot/isabela_scene_test/tests/test_trilha_3_boss_skins_radar.gd) ampliado e passando sem nenhum erro de console.

## [2026-11-17 15:31] Correção Real do Cabelo na Malha 3D (`SK_Isabela_Leeloo.glb` no Blender) & Atualização de `GEMINI.md`
- **Documentação ([GEMINI.md](file:///D:/Godot/isabela_scene_test/GEMINI.md))**: atualizado mapa para `46` scripts e `19` suítes de teste, registrando Mechs animados (`5/10/15/20`), escudo de 30% nos capacetes, correções da Arma Laser, Ciclo Dia/Noite (`1 min = 2h`) e correção do cabelo da Leeloo (backup em `.backups/GEMINI.md.*.bak`).
- **Backups criados**: `.backups/SK_Isabela_Leeloo.glb.20261117_152956.bak` e atualização de [player_skin_helper.gd](file:///D:/Godot/isabela_scene_test/scripts/game/player_skin_helper.gd).
- **Remoção de primitivas (`player_skin_helper.gd`)**: removida `_ensure_hair_crown_fix()` (`HairCrownFill` em esfera/caixas), mantendo apenas `_set_hair_visible()` para ocultar `SK_Isabela_Hair` ao equipar `helmet_a`/`helmet_b`.
- **Edição 3D no Blender (`assets/SK_Isabela/SK_Isabela_Leeloo.glb`)**:
  - Recuados os vértices de `M_Isabela_Hair_Scalp` (`-11 mm`) e topo de `SK_Isabela_Body` (`z > 1.675`, `-9 mm`) que atravessavam por cima dos fios, com escurecimento de `M_Isabela_Hair_Scalp` para tom de raiz.
  - Elevadas as mechas superiores de `M_Isabela_Hair` (`+4..8 mm`) e duplicados/rotacionados (`+18°`) os cartões reais de cabelo com UV/pesos preservados na coroa.

## [2026-11-17 15:05] Topo do Cabelo (Coroa) & Ocultação sob Capacete (`player_skin_helper.gd`)
- **Backups criados**: `.backups/player_skin_helper.gd.20261117_150348.bak` e `.backups/CHANGELOG.md.20261117_150348.bak`.
- **Cabelo sem falha no topo ([player_skin_helper.gd](file:///D:/Godot/isabela_scene_test/scripts/game/player_skin_helper.gd#L107-L143))**: `_ensure_hair_crown_fix()` eleva a malha de cabelo em `+0.012 m` (`12 mm`, escala `1.03 x 1.02 x 1.03`) e adiciona `HairCrownFill` no osso `Head` cobrindo o couro cabeludo.
- **Sem vazamento no capacete (`_set_hair_visible`)**: quando `helmet_a`/`helmet_b` está equipado, oculta a malha de cabelo e `HairCrownFill`; ao quebrar (`"none"`), reexibe automaticamente.

## [2026-11-17 14:53] Ciclo Dia / Noite (`1 min = 2 horas` — `day_night_cycle.gd`)
- **Backups criados**: `.backups/arena_coordinator.gd.20261117_145259.bak` e `.backups/CHANGELOG.md.20261117_145259.bak`.
- **Novo módulo ([day_night_cycle.gd](file:///D:/Godot/isabela_scene_test/scripts/game/day_night_cycle.gd), 129 linhas)**:
  - Avança a hora do jogo na proporção `2.0 / 60.0` horas por segundo (`1 min real = 2h no jogo`, ciclo de 24h em `12 min`).
  - Interpola `DirectionalLight3D` (inclinação, cor, energia), `ProceduralSkyMaterial` (topo/horizonte/chão) e `Environment` (luz ambiente e neblina) nas fases `AMANHECER`, `DIA`, `ENTARDECER` e `NOITE`, exibindo relógio discreto no topo do HUD (`HH:MM • FASE`).
- **Integração ([arena_coordinator.gd](file:///D:/Godot/isabela_scene_test/scripts/game/arena_coordinator.gd#L74-L75))**: instancia `DayNightCycle` em `_bind_scene_nodes()` preservando `299` linhas (`< 300`).
- **Teste ([test_day_night_cycle.gd](file:///D:/Godot/isabela_scene_test/tests/test_day_night_cycle.gd))**: valida taxa `1 min = 2h`, transições `DIA` / `ENTARDECER` / `NOITE`, energia da luz noturna e wrap de `24h`.

## [2026-11-17 14:50] Ajuste de Encaixe do Capacete no Osso `Head` (`player_skin_helper.gd`)
- Ajustado offset de `SM_Helmet_A`/`SM_Helmet_B` em `BoneAttachment3D` para `position = Vector3(0.0, -0.185, 0.015)` (`scale = Vector3.ONE`) em [player_skin_helper.gd](file:///D:/Godot/isabela_scene_test/scripts/game/player_skin_helper.gd#L136-L137), encaixando o colar do capacete sobre a cabeça em vez de flutuar no topo.

## [2026-11-17 14:44] Correções nos Boosters da Arma Laser (`reload_speed` e feixe perfurante)
- **Backups criados**: `.backups/*.20261117_144353.bak` para `scripts/game/{weapon_loadout,weapon_manager}.gd` e `CHANGELOG.md`.
- **Resfriamento do Laser (`weapon_loadout.gd:266`)**: `regen_delay_left` agora decai por `delta * cool_mult` (`reload_speed_multiplier`), reduzindo também o atraso inicial antes do resfriamento ao pegar *Mãos Ágeis*.
- **Feixe Visual Perfurante (`weapon_manager.gd:190-192`)**: quando o raio laser perfura um inimigo e `hit.is_empty()` nos segmentos seguintes, `end_pos` é estendido até `origin + dir * max_r` em vez de parar no último alvo.
- **Testes (`tests/test_laser_boosters.gd`)**: valida `weapon_damage`, `ammo_capacity`, `blast_pierce`, `reload_speed` e `fire_rate` na `laser_gun`.

## [2026-11-17 14:34] Escudo de 30% do Life para Capacetes (`helmet_a` / `helmet_b`)
- **Backups criados**: `.backups/*.20261117_141705.bak` para `data/game_balance.json`, `scripts/game/{player_controller,player_skin_helper,hud_controller,wave_spawner,pickup_crate}.gd` e `CHANGELOG.md`.
- **Balanceamento & Pickups (`data/game_balance.json`, `balance_db.gd`, `wave_spawner.gd`)**:
  - Adicionados `helmet_a` e `helmet_b` em `pickups` com `shield_max_hp_percent = 0.30` e `drop_weight_base = 0.14` (removida trava `== 2` em `balance_db.gd` para `>= 2`).
  - `WaveSpawner.choose_crate_type()` agora sorteia `helmet_a`/`helmet_b` entre os drops da arena.
- **Escudo & Quebra Visual (`player_controller.gd`, `player_skin_helper.gd`, `hud_controller.gd`)**:
  - Equipar no início da partida ou coletar `helmet_a`/`helmet_b` na arena concede `shield_hp = 30%` de `max_hp` e acopla o capacete 3D via `PlayerSkinHelper.attach_helmet_on_player()`.
  - `take_damage()` absorve dano no escudo primeiro; quando `shield_hp <= 0`, o capacete é removido da cabeça e o dano excedente atinge `current_hp`.
  - `HUDController._on_hp_changed()` exibe `• ESCUDO X` ao lado do HP enquanto `shield_hp > 0`.
- **Testes (`tests/test_helmet_shield.gd`)**: valida escudo de 30%, absorção, quebra visual ao zerar e reequipamento ao pegar outro capacete (`ALL_TESTS_PASSED`).

## [2026-11-17 13:57] Substituição dos Droids Procedurais por 4 Mechs Animados (1 a cada 5 ondas)
- **Backups criados**: `.backups/*.20261117_135207.bak` para `data/game_balance.json`, `scripts/game/{balance_db,wave_spawner,enemy_variants_helper,enemy_droid,orbital_drop_pod,hud_radar,droid_destruction_vfx}.gd`, `tests/{test_v3_features,test_trilha_3_boss_skins_radar}.gd` e `CHANGELOG.md`.
- **Assets & Cenas (`.gltf` + `.tscn`)**:
  - Adicionados `assets/SK_Mech_{Leela,Mike,Stan,George}/SK_Mech_*.gltf` (pacote Quaternius Textured glTF com `Skeleton3D`, buffers/texturas embutidos e `18–20` animações).
  - Criadas as cenas [mech_leela.tscn](file:///D:/Godot/isabela_scene_test/scenes/game/mech_leela.tscn) (`1.65 m`), [mech_mike.tscn](file:///D:/Godot/isabela_scene_test/scenes/game/mech_mike.tscn) (`1.85 m`), [mech_stan.tscn](file:///D:/Godot/isabela_scene_test/scenes/game/mech_stan.tscn) (`2.05 m`) e [mech_george.tscn](file:///D:/Godot/isabela_scene_test/scenes/game/mech_george.tscn) (`2.15 m`).
- **Balanceamento & Ondas (`data/game_balance.json`, `balance_db.gd`, `wave_spawner.gd`)**:
  - Removidos `droid_spider` e `droid_sawbox` da rotação de ondas; substituídos por `mech_tiers` em intervalos de 5 ondas: **Onda 5 (`mech_leela`)**, **Onda 10 (`mech_mike`)**, **Onda 15 (`mech_stan`)**, **Onda 20 (`mech_george`)**.
  - Atualizado `wave_spawner.gd` com `MECH_SCENES`, `orbital_drop_pod.gd` (`mech_leela` a partir da Onda 10), `hud_radar.gd` (cores dedicadas por mech), `droid_destruction_vfx.gd` (`is_tall` para `mech_*`), `enemy_droid.gd` (ranged burst em `mech_leela`/`mech_george`) e `enemy_variants_helper.gd` (`_tick_mech` dirigindo `AnimationPlayer` para `Idle`/`Run`/`Shoot`/`Punch`).
- **Testes (`tests/test_mech_enemies_replacement.gd`, `test_v3_features.gd`, `test_trilha_3_boss_skins_radar.gd`)**:
  - Criada suíte TDD [test_mech_enemies_replacement.gd](file:///D:/Godot/isabela_scene_test/tests/test_mech_enemies_replacement.gd) validando introdução nas Ondas 5/10/15/20, ausência de `spider`/`sawbox`, `AnimationPlayer`, `configure_from_balance()` e cápsula orbital.

## [2026-11-17 01:19] Rig + Animação de Corrida do 1º Boss & Texturas/Normais Estilo Alien (Wan2GP)
- **Backups criados**: `.backups/alien_textures_20261117/` e `.backups/` para `SK_Boss_Reaper.glb`.
- **Rig & Animação de Membros do 1º Boss ([SK_Boss_Reaper.glb](file:///c:/Users/sphok/isabela-3d-survival/assets/SK_Boss_Reaper/SK_Boss_Reaper.glb))**:
  - Malha otimizada e rigada no Blender 5.3 com `ReaperArmature` (`Skeleton3D` de `15` ossos) e animações `Run`, `Idle` e `Attack` exportadas em glTF `+Y Up`.
  - Integradas em [`scripts/game/boss_visuals_helper.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/boss_visuals_helper.gd) (`238` linhas) e [`scripts/game/boss_sentinel.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/boss_sentinel.gd) (`236` linhas): animação `Run` escalada pela velocidade no estado `CHASE`, `Attack` no `WINDUP`/impacto e `Idle` em repouso.
- **Texturas & Micro-Normais estilo *Alien* (Ridley Scott) via Wan2GP (`qwen_image_21_7B`, `denoising_strength=0.44`)**:
  - Aprimorados mapas `BaseColor` + relevo micro-normal Sobel RNM (`*_Normal.png`) para **Mapa** (`ENV_DesertCoast`), **Inimigos** (`SK_Droid_Small`, `SK_Droid_Tall`), **Armas** (`Pistol`, `Shotgun`, `RocketLauncher`, `Katana`, `LaserGun`, `Lightsaber`) e **Personagem** (`SK_Isabela` / `Leeloo`, sem alterar `SK_Isabela.glb`).
  - Reimportação no Godot concluída com `186/187` `.import` em `compress/mode=2` (apenas `main_menu_bg.png.import` em `mode=0`), **`15/15` suítes headless aprovadas** e **`45/45` scripts `< 300` linhas**.

## [2026-11-16 23:36] Integração do Modelo 3D do Primeiro Boss (`SK_Boss_Reaper.glb`)
- **Asset integrado**: copiado `2026-11-16-23h08m46s_seed3150903_Bronze lion statue.glb` (gerado via TRELLIS.2 no Wan2GP) para [`assets/SK_Boss_Reaper/SK_Boss_Reaper.glb`](file:///c:/Users/sphok/isabela-3d-survival/assets/SK_Boss_Reaper/SK_Boss_Reaper.glb) e importado no Godot.
- **Auto-escala e aterramento (`y = 0`)** em [`scripts/game/boss_visuals_helper.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/boss_visuals_helper.gd): normaliza o AABB do `.glb` (`~1.0 m` centrado na origem) para `height_m = 2.45 m`, apoia os pés em `y = 0.0` e alinha a frente para `-Z`.
- **Ordem dos Bosses** em [`data/game_balance.json`](file:///c:/Users/sphok/isabela-3d-survival/data/game_balance.json): `white_reaper` definido como o **1º Boss (Onda 5)** em `rotation_order`, com proteção em [`scripts/game/player_skin_helper.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/player_skin_helper.gd) para preservar o esqueleto/armas caso o `.glb` ainda esteja sem rig (`Skeleton3D`).

## [2026-11-16 15:57] Implementação da Trilha 3 (Bosses Rotativos, Skins & Arquétipos, Mini-Radar)
- **Backups criados**: `.backups\trilha3_20261116\*`.
- **Pilar 3.1 — Bosses Rotativos & Chuva de Cápsulas**:
  - Adicionados [`scripts/game/boss_sentinel.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/boss_sentinel.gd), [`scripts/game/boss_visuals_helper.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/boss_visuals_helper.gd), [`scenes/game/boss_sentinel.tscn`](file:///c:/Users/sphok/isabela-3d-survival/scenes/game/boss_sentinel.tscn), [`scripts/game/orbital_drop_pod.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/orbital_drop_pod.gd) e [`scripts/game/hud_boss_bar.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/hud_boss_bar.gd).
  - Configurados os 3 Bosses rotativos a cada 5 ondas (`valkyrie_skull` Onda 5, `white_reaper` Onda 10, `anubis_phantom` Onda 15) em [`data/game_balance.json`](file:///c:/Users/sphok/isabela-3d-survival/data/game_balance.json) e [`scripts/game/balance_db.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/balance_db.gd), com Enrage aos 50% HP (`+25%` velocidade + salva de 4 cápsulas), cápsulas destrutíveis, carta `legendary` garantida em [`scripts/game/upgrade_system.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/upgrade_system.gd) e drop imediato de Vida + Munição.
- **Pilar 3.2 — Skins Jogáveis, Capacetes & Arquétipos (Buff + Debuff)**:
  - Adicionados [`scripts/game/player_skin_helper.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/player_skin_helper.gd) e [`scripts/game/skin_selector_modal_ui.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/skin_selector_modal_ui.gd), integrados em [`scripts/game/settings_manager.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/settings_manager.gd) (`user://unlocks.cfg` + `unlock_all_for_test`), [`scripts/game/main_menu_controller.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/main_menu_controller.gd), [`scripts/game/player_controller.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/player_controller.gd) e [`scripts/game/weapon_loadout.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/weapon_loadout.gd), preservando o pool `O(1)` de 7 armas.
- **Pilar 3.3 — Mini-Radar Tático no HUD**:
  - Adicionado [`scripts/game/hud_radar.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/hud_radar.gd) via `_draw()` com throttle de `0.06 s` e projeção relativa ao `yaw` do jogador, integrado em [`scripts/game/hud_controller.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/hud_controller.gd).
- **Testes**:
  - Adicionada suíte [`tests/test_trilha_3_boss_skins_radar.gd`](file:///c:/Users/sphok/isabela-3d-survival/tests/test_trilha_3_boss_skins_radar.gd); validada regra `< 300` linhas (`MAX_LINES=299`, `VIOLATIONS=0`).

## [2026-11-16 15:07] Ficha Completa de Comportamento & Ataques dos 3 Bosses (`TRILHA_3_BOSSES_DESIGN.md`)
- **Backups criados**: `D:\Godot\isabela_scene_test\.backups\TRILHA_3_PLAN.md.20261116_150706.bak`, `CHANGELOG.md.20261116_150706.bak`.
- **Criado [`docs/TRILHA_3_BOSSES_DESIGN.md`](file:///D:/Godot/isabela_scene_test/docs/TRILHA_3_BOSSES_DESIGN.md)**: ficha estruturada em 4 seções (*Identidade & Leitura Visual*, *Comportamento & Fluxo de IA*, *Movimentos & Kit de Ataques com Telegrafia* e *Skin Jogável*) para os 3 Bosses rotativos (`Valkyrie Skull`, `White Reaper`, `Anubis Phantom`).
- **Atualizado [`docs/TRILHA_3_PLAN.md`](file:///D:/Godot/isabela_scene_test/docs/TRILHA_3_PLAN.md)**: adicionada referência direta para `docs/TRILHA_3_BOSSES_DESIGN.md` na seção *Identidade, Armas & Animações Personalizadas por Boss*.

## [2026-11-16 13:02] Design Completo da Trilha 3 (Bosses Rotativos, Desbloqueio de Skins & Arquétipos Buff/Debuff)
- **Backups criados**: `D:\Godot\isabela_scene_test\.backups\TRILHA_3_PLAN.md.20261116_*.bak`, `CHANGELOG.md.20261116_*.bak`.
- **Atualizado [`docs/TRILHA_3_PLAN.md`](file:///D:/Godot/isabela_scene_test/docs/TRILHA_3_PLAN.md)**:
  - Consolidados os **3 Bosses Rotativos** (Onda 5 `Valkyrie Skull`, Onda 10 `White Reaper`, Onda 15 `Anubis Phantom`), armas exclusivas, animações/ações únicas, anti-cheese em plataformas elevatórias, **Chuva de Cápsulas (`orbital_drop_pod.gd`)**, **2 Fases + Enrage aos 50% HP** e recompensa (`Lendária` + 1 Vida + 1 Munição + desbloqueio da skin).
  - Detalhado o sistema de **Skins Desbloqueáveis & Arquétipos (`player_skin_helper.gd`)** com tabela exata de **Buffs e Debuffs de equilíbrio** (`Assalto Ágil`, `Tanque Blindado`, `Caçador de Precisão`), persistência `user://unlocks.cfg` e plano de testes TDD (`test_trilha_3_boss_skins_radar.gd`).

## [2026-11-16 12:50] Referências T-Pose do Boss (`docs/references/`) & Brainstorm Pilar 3.1
- **Backups criados**: `D:\Godot\isabela_scene_test\.backups\TRILHA_3_PLAN.md.20261116_*.bak`, `CHANGELOG.md.20261116_*.bak`.
- **Adicionadas referências em T-Pose (fundo branco, mãos abertas 5 dedos)** em `docs/references/` (com `.gdignore` para não inflar importação do Godot):
  - `docs/references/boss_char1_skull_cyborg_tpose.jpg`
  - `docs/references/boss_char2_white_android_tpose.jpg`
  - `docs/references/boss_char3_anubis_ninja_tpose.jpg`
- **Atualizado [`docs/TRILHA_3_PLAN.md`](file:///D:/Godot/isabela_scene_test/docs/TRILHA_3_PLAN.md)**: Seção 1 (*Pilar 3.1 — Boss Orbital*) detalhada com contrato desacoplado de asset (`SK_Boss_Orbital.glb`), **Chuva de Cápsulas / Reforços** (`orbital_drop_pod.gd`), **2 Fases + Enrage aos 50% HP** (`boss_sentinel.gd`) e `hud_boss_bar.gd`.

## [2026-11-16 12:31] Planejamento da Trilha 3 & Atualização Completa do `GEMINI.md`
- **Backups criados**: `D:\Godot\isabela_scene_test\.backups\GEMINI.md.20261116_123058.bak`, `CHANGELOG.md.20261116_123058.bak`.
- **Adicionado [`docs/TRILHA_3_PLAN.md`](file:///D:/Godot/isabela_scene_test/docs/TRILHA_3_PLAN.md)**: especificação técnica detalhada da Trilha 3 para implementação posterior (`BossSentinel` + `OrbitalStrikeVFX` + `HUDBossBar`, `PlayerSkinHelper` com 4 skins + capacetes `SM_Helmet_A/B`, `HUDRadar` via `_draw()` e suíte TDD `test_trilha_3_boss_skins_radar.gd`), preservando trava `< 300` linhas e otimizações de VRAM/pooling.
- **Atualizado [`GEMINI.md`](file:///D:/Godot/isabela_scene_test/GEMINI.md)**: documentada a arquitetura atual (`38` scripts, `7` cenas jogáveis, `14` suítes headless, CI `.github/workflows/godot-tests.yml`, invariantes de compressão VRAM e pooling `O(1)`) e adicionada a Seção 6 com contexto completo de continuidade para próximas sessões e colaboradores.

## [2026-11-16 12:16] Otimização de Desempenho, VRAM e Troca de Armas `O(1)`
- **Backups criados**: `D:\Godot\isabela_scene_test\.backups\*.20261116_*.bak`.
- **Troca de armas `O(1)` sem engasgos**:
  - Adicionado [`scripts/game/weapon_pool_helper.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/weapon_pool_helper.gd) e integrado em [`scripts/game/weapon_manager.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/weapon_manager.gd) e [`scripts/game/fps_viewmodel.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/fps_viewmodel.gd): todas as 7 armas são pré-instanciadas uma única vez nos sockets TPS e FPS e alternadas via `visible`, além de remover trilhas `TYPE_SCALE_3D` degeneradas de `ThumbDistal` em `FPS_Arms.glb`.
  - Redução medida (`Forward+` RTX 3060): troca de arma TPS caiu de **`323–630 ms` → `8.6–37.2 ms`** (`1.8 ms` em re-seleção) e FPS de **`65–516 ms` → `2.7–7.8 ms`**.
- **Compressão VRAM & Orçamento de Texturas**:
  - Atualizados `182` arquivos `.png.import`/`.jpg.import` 3D para `compress/mode=2` (VRAM Compressed BPTC/S3TC) com `process/size_limit` (`2048` para `SM_Ship`/`SK_Isabela*`/`ENV_DesertCoast`, `1024` para armas/droids/caixas/capacetes), preservando `assets/ui/main_menu_bg.png`.
  - Redução medida: **texturas de `1.815 MB` → `299.3 MB`** (`-83,5%`) e **VRAM total de `2.037,8 MB` → `427,0 MB`** (`-79%`).
- **VFX/Explosões Compartilhados, Geometria & HUD sem Alocações**:
  - [`scripts/game/weapon_vfx.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/weapon_vfx.gd) e [`scripts/game/droid_destruction_vfx.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/droid_destruction_vfx.gd): cache estático de `Mesh`/`Shape3D`/`StandardMaterial3D` e `warmup()` no boot da arena via [`scripts/game/arena_coordinator.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/arena_coordinator.gd) (que também desativa `cast_shadow` em `SM_Ship` e faz throttle de `0.08 s` no sort de ondulação da água).
  - [`scripts/game/arena_electric_perimeter.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/arena_electric_perimeter.gd), [`scripts/game/arena_props.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/arena_props.gd) e [`scenes/game/playable_arena.tscn`](file:///D:/Godot/isabela_scene_test/scenes/game/playable_arena.tscn): malhas compartilhadas low-poly nos 16 postes, `WaterPlane` `32×32`, remoção de sombras em frisos/capacetes decorativos (`PRIMS` caiu de **`1.041.286` → `449.978`**, `DRAW_CALLS` **`286` → `172`**).
  - [`scripts/game/hud_weapon_bar.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/hud_weapon_bar.gd): reutilização de `StyleBoxFlat` em cache + dirty-check eliminando recriação por quadro.
- **Preset de Qualidade Gráfica (`Baixo` / `Médio` / `Alto`)**:
  - Adicionado `graphics_quality` em [`scripts/game/settings_manager.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/settings_manager.gd) e [`scripts/game/settings_modal_ui.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/settings_modal_ui.gd) (padrão `2 = Alto`), controlando escala 3D, SSR, glow e sombras em tempo real.
- **Testes**:
  - Adicionada suíte [`tests/test_optimization_and_pooling.gd`](file:///D:/Godot/isabela_scene_test/tests/test_optimization_and_pooling.gd); **`14/14` suítes headless passaram** (`TESTS_SUMMARY: total=14 failed=0`) e `0` violações `< 300` linhas (`MAX_LINES=299`).

## [2026-11-16 11:13] Cena Principal e Atalho do Desktop (`main_menu.tscn`)
- **Backups criados**: `D:\Godot\isabela_scene_test\.backups\project.godot.20261116_111337.bak`, `CHANGELOG.md.20261116_111337.bak`, `Iniciar Isabela 3D.bat.20261116_111337.bak`.
- **`project.godot` (linha 14)**:
  - **Removido**: `run/main_scene="res://scenes/test_fase1_helmets.tscn"`
  - **Adicionado**: `run/main_scene="res://scenes/game/main_menu.tscn"`
  - **Motivo**: permitir que `F5` no editor Godot e a execução padrão do projeto abram diretamente o jogo pelo menu principal atualizado.
- **`C:\Users\thiag\Desktop\Iniciar Isabela 3D.bat` (linhas 6–7)**:
  - **Removido**: `SCENE_PATH=res://scenes/game/playable_arena.tscn` / `SCENE_FILE=%PROJECT_DIR%\scenes\game\playable_arena.tscn`
  - **Adicionado**: `SCENE_PATH=res://scenes/game/main_menu.tscn` / `SCENE_FILE=%PROJECT_DIR%\scenes\game\main_menu.tscn`

## [2026-11-15] 3rd-Person Arm/Mesh Fix, Sniper Rifle (Slot 2), FPS Optic Transparency & Arena Elevators
- **`assets/SK_Isabela/SK_Isabela_Leeloo.glb` & `scripts/game/player_animator.gd`**:
  - Fixed 3rd-person character distortions by removing stray hand/finger vertices and weights from `SK_Isabela_Leeloo_Legs`, removing jagged `SK_Isabela_Leeloo_Straps`, cleaning finger weights on `SK_Isabela_Top`, and pushing clothing/hair meshes cleanly outside `SK_Isabela_Body` (while keeping base `SK_Isabela.glb`, `main_isabela_scene.tscn`, and `test_fase1..5_*.tscn` untouched).
  - Adjusted `Sword_Idle` (`uidle == "sword"`) left-arm guard pose in `player_animator.gd` (`LeftShoulder`, `LeftUpperArm`, `LeftLowerArm`) to prevent backward ribcage twist.
- **`assets/SM_Weapon_Sniper/SM_Weapon_Sniper.glb`, `data/game_balance.json`, `scripts/game/weapon_manager.gd`, `scripts/game/hud_weapon_bar.gd`, `scripts/game/game_over_modal_ui.gd`, `scripts/game/procedural_sfx.gd` & `scripts/game/audio_manager.gd`**:
  - Replaced slot 2 (`lightsaber`) with **`sniper` ("Rifle Sniper")** featuring a dedicated 3D rifle & scope model (`Scope`, `ScopeLens`, `Muzzle`), `hitscan_pierce` delivery (`damage = 95.0`, `headshot_multiplier = 3.5`, `pierce_count = 2`, `spread_aim_deg = 0.02`, `mag_size = 5`, `grip_pose = "both"`), golden sniper tracer + headshot crit sparks, `"SNIPER"` HUD badge, and `"sniper"` high-caliber shot SFX.
- **`scripts/game/fps_optic_helper.gd` (new), `scripts/game/fps_viewmodel.gd`, `scripts/game/hud_crosshair.gd` & `scripts/game/hud_controller.gd`**:
  - Added `FPSOpticHelper` to make scope/optic housings and lenses transparent during 1st-person ADS (and restore opaque materials on exit), aligned `WEAPON_TWEAKS["sniper"]` to the scope centerline, and added precision optic & sniper mil-dot reticles in `hud_crosshair.gd`.
- **`scripts/game/arena_elevators.gd` (new), `scripts/game/arena_coordinator.gd`, `scripts/game/wave_spawner.gd`, `scripts/game/enemy_variants_helper.gd`, `scripts/game/enemy_droid.gd` & `tests/test_arena_elevators.gd` (new)**:
  - Added 4 oscillating `AnimatableBody3D` elevator platforms (`y = 0.35m..4.2m`, `sync_to_physics = true`) with a 25% ranged-enemy spawn chance (`droid_tall`, `droid_spider`) and ledge-holding AI (`should_hold_elevator_ledge`).

## [2026-11-15] Leeloo Visual Upgrade, Electric Perimeter Hazard, Wave 5/10 Enemies & Expanded SFX
- **`assets/SK_Isabela/SK_Isabela_Leeloo.glb` & `scenes/game/player_isabela.tscn`**:
  - Created Leeloo-inspired playable character variant in Blender (`SK_Isabela_Leeloo.glb`, preserving the exact 84-bone `Armature_Isabela`, 52 ARKit blendshapes, `SpringBoneSimulator3D`, and `WeaponSocket`) with orange Chanel bob hair, orange tactical jumpsuit, and iconic orange harness straps (`T_Leeloo_Hair_BaseColor.png`, `T_Leeloo_Top_BaseColor.png`, `T_Leeloo_Lingerie_BaseColor.png`), leaving base `SK_Isabela.glb`, `main_isabela_scene.tscn`, and `test_fase1..5_*.tscn` untouched.
- **`scripts/game/arena_electric_perimeter.gd` & `scripts/game/arena_coordinator.gd`**:
  - Added `ArenaElectricPerimeter` with 16 perimeter pylons, pulsing cyan-blue barrier rails, animated jagged `ImmediateMesh` arcs, and a `10.0 dmg/s` electric shock hazard (`0.5s` tick interval) with inward knockback and `electric_shock` SFX when touching the arena boundary (`playable_radius_m - perimeter_electric_width_m`).
- **`data/game_balance.json`, `scripts/game/balance_db.gd`, `scripts/game/wave_spawner.gd`, `scripts/game/enemy_droid.gd`, `scripts/game/enemy_variants_helper.gd`, `scenes/game/droid_spider.tscn`, `scenes/game/droid_sawbox.tscn`**:
  - Added `droid_spider` (Arachnotron-inspired 6-legged spider with dorsal plasma autocannon, `base_hp = 260.0`, introduced at **Wave 5+**) and `droid_sawbox` (armored cube with spinning lateral circular saws, `base_hp = 420.0`, highest HP of all 4 enemies, introduced at **Wave 10+**).
- **`scripts/game/procedural_sfx.gd` & `scripts/game/audio_manager.gd`**:
  - Added procedural `AudioStreamWAV` generation and preloading for `electric_shock`, `droid_small`, `droid_tall`, `droid_spider_cannon`, `droid_spider_step`, `droid_sawbox_hum`, `droid_sawbox_impact`, `enemy_hit`, `enemy_death`, `rocket_explode`, and `laser_overheat`.
- **`tests/test_v3_features.gd`**:
  - Added dedicated headless verification suite covering the electric perimeter (`~10 dmg/s`), Wave 5/10 enemy progression & HP ordering, all new `ProceduralSFX` IDs, and `SK_Isabela_Leeloo.glb` integration.

## [2026-11-15] Upgrade Confirm-Only, Auto-Reload, Laser Overheat/Cooldown Anims & "Você Morreu"
- **`scripts/game/upgrade_modal_ui.gd`**:
  - Clicking the upgrade card body (`btn.pressed`) now only focuses/highlights the card (`_set_selected_index`), requiring an explicit click on the **CONFIRMAR** button (or `1`/`2`/`3` / gamepad `X`/`Y`/`B`) to apply the upgrade.
- **`scripts/game/player_combat_helper.gd` & `scripts/game/fps_viewmodel.gd`**:
  - Added `_sync_weapon_state_anims` to detect state transitions on both manual `[R]` and automatic empty-magazine reloads, triggering reload SFX + TPS/FPS reload animations.
  - Added `trigger_laser_overheat` (thermal jitter, tilted vent pose, pulsing orange-red overlay) and `trigger_laser_ready` (cool-down snap-back + cyan ready flash) when the Laser Gun overheats and cools down.
- **`scripts/game/game_over_modal_ui.gd`**:
  - Updated the centered Game Over title to **`VOCÊ MORREU`** alongside the existing summary and menu buttons (`JOGAR NOVAMENTE`, `MENU PRINCIPAL`).
- **`tests/test_menus_and_settings.gd`**:
  - Added unit coverage for confirm-only card selection, `VOCÊ MORREU` title, and FPS viewmodel reload/overheat/ready animations.

## 2026-11-13
- **Created** `data/game_balance.json`: Added full playable wave-survival game configuration (arena bounds, `SK_Isabela` player physics/camera/dash, 6 weapons with combat balance and 3D `.glb` modeling specs/offsets, 2 pickup crates, `SK_Droid_Small` & `SK_Droid_Tall` enemy stats, wave progression curves, rarity weights, and 10 stackable upgrades). Validated via Godot 4.7.2 `--headless` JSON parse check (`JSON_OK weapons=6 pickups=2 upgrades=10`).
- **Created** `GAME_DESIGN.md`: Added complete Game Design & Godot 4.7.2 modular technical architecture document (`res://scenes/game/` + `res://scripts/game/`), non-interference rules preserving `main_isabela_scene.tscn`, verified bone/blendshape references, 3D modeling briefs for `@blender-author`, and verification acceptance criteria.
- **Created** `scripts/game/balance_db.gd` (`111` lines): JSON configuration loader (`res://data/game_balance.json`), weapon/pickup/enemy/progression lookup, and wave/XP math helpers (`get_wave_spec`, `get_xp_for_next_level`, `get_waves_cfg`).
- **Created** `scripts/game/upgrade_system.gd` (`158` lines): Stackable upgrade accumulator, weighted rarity roller with wave pity, and duplicate-free 3-card draft generator. Replaced global `BalanceDB` type reference with explicit `preload` (`BalanceDBRef`) after initial headless test uncovered Godot class-cache parse failure prior to `--import`.
- **Created** `scripts/game/input_setup.gd` (`47` lines): Idempotent `InputMap` bootstrap for WASD/Jump/Sprint/Dash/Fire/Aim/Reload/Slots 1–6/Upgrade keys.
- **Created** `scripts/game/weapon_loadout.gd` (`250` lines): Per-slot runtime ammo, reload timer, Laser Gun battery drain/overheat/manual vent, 3-hit melee combo progression, and upgrade stat scaling.
- **Created** `scripts/game/game_manager.gd` (`154` lines): Game state machine (`PLAYING`, `UPGRADE_MODAL`, `PAUSED`, `GAME_OVER`), XP/level-up queueing, wave clear upgrade guarantee, and lifesteal/countdown signals.
- **Created** `tests/test_balance_and_upgrades.gd` (`97` lines) & `tests/test_combat_core.gd` (`112` lines): Headless Godot 4.7.2 TDD verification suites covering JSON schema, wave scaling, 3-card drafts, 6-weapon firing/reload/overheat/combo logic, and wave transitions.
- **Created** `scripts/game/wave_spawner.gd` (`177` lines), `scripts/game/pickup_crate.gd` (`109` lines), `scripts/game/projectile_controller.gd` (`191` lines), and `tests/test_spawner_projectiles_pickups.gd` (`121` lines).
  - Updated `wave_spawner.gd` low-HP `health_crate` weight boost from `2.8x` to `3.2x` after initial TDD probability run (`64/100`), then verified `ALL_TESTS_PASSED: test_spawner_projectiles_pickups`.
- **Created** `scripts/game/player_controller.gd`, `scripts/game/player_camera_rig.gd`, `scripts/game/player_animator.gd`, `scripts/game/weapon_manager.gd`, `scripts/game/enemy_droid.gd`, `scripts/game/upgrade_modal_ui.gd`, `scripts/game/hud_controller.gd`, `scripts/game/arena_coordinator.gd`, plus TDD suites `tests/test_player_enemy_weapons.gd` and `tests/test_hud_and_arena_loop.gd`.
  - Refactored `PlayerCameraRig` out of `player_controller.gd` (`259` lines) and `UpgradeModalUI` out of `hud_controller.gd` (`280` lines) so every script stays `<= 280` lines.
  - Added idempotent `_ensure_ui()`/`_ensure_layout()`, `_connect_once()` signal guards, `InputSetupRef.ensure_default_actions()` inside `PlayerController`, `Target_Foot_L`/`Target_Foot_R` `TwoBoneIK3D` stride support in `enemy_droid.gd`, and dynamic `ripple_center_0..3` shallow-water tracking in `arena_coordinator.gd`.
  - Verified all 5 headless TDD suites (`test_balance_and_upgrades.gd`, `test_combat_core.gd`, `test_spawner_projectiles_pickups.gd`, `test_player_enemy_weapons.gd`, `test_hud_and_arena_loop.gd`) pass (`exit 0`).

## [2026-11-13 20:48] WaveSpawner, GameManager, WeaponManager, HUD Refactor & E2E Stabilization
- **`scripts/game/wave_spawner.gd`**:
  - Removed `_entities_root.add_child(enemy)` before `enemy.global_position = spawn_pos` in `_spawn_enemy` and `_entities_root.add_child(crate)` before position assignment in `_instantiate_crate`.
  - Added pre-insert local `position = _entities_root.to_local(...)` assignment before `add_child(...)` so spawned droids/crates never overlap `Player` at `(0,0,0)` inside `PhysicsServer3D`.
- **`scripts/game/upgrade_system.gd` & `scripts/game/game_manager.gd`**:
  - Added `DEFAULT_STATS` and `UpgradeSystem.reset()`; updated `GameManager.start_run()` to reuse/reset `upgrades` and `loadout` instead of reallocating new instances so `Player`, `WeaponManager`, `HUD`, and `PickupCrate` keep referencing the single live objects.
- **`scripts/game/weapon_manager.gd`**:
  - Fixed GDScript `Array[RID]` ternary type error in `_fire_piercing_laser`; separated `_get_combat_ray_origin(muzzle_fallback)` (chest/weapon height `Y+0.94m`) from `muzzle_pos` for physics raycast/rocket origin while preserving `muzzle_pos` for flash/beam FX.
- **`scripts/game/hud_weapon_bar.gd` (new, 75 lines), `scripts/game/hud_controller.gd` (345 -> 298 lines), `scripts/game/player_controller.gd` (304 -> 297 lines)**:
  - Extracted `HUDWeaponBar` (`hud_weapon_bar.gd`) and tightened `PlayerController` movement/signal wiring so every script in `scripts/game/` remains strictly under 300 lines.
- **`tests/test_playable_arena_e2e.gd`**:
  - Added PhysicsServer3D sync steps (`await _step_frames`), dedicated target dummy checks for Katana/LaserGun/RocketLauncher, Health+Ammo `PickupCrate` verification using `get_slot_hud_state`, and Level-Up/Wave-Clear 3-card modal + Wave 2 transition checks. Verified all 6 `--headless` suites green.

## [2026-11-13 20:57] Visual Polish — Upgrade Modal Padding, HUD Outlines & Animator Pose
- **`scripts/game/upgrade_modal_ui.gd`**:
  - Wrapped card `VBoxContainer` inside a `MarginContainer` (`16px` horizontal, `14px` vertical margins) so card text no longer hugs colored card borders.
- **`scripts/game/hud_controller.gd`**:
  - Added dark `font_outline_color` (`outline_size = 4`) in `_make_label` for crisp HUD readability against bright sky and dark water; kept file at `292` lines (`< 300`).
- **`scripts/game/player_animator.gd`**:
  - Fixed firearm `RightUpperArm` pose (`-1.18` overhead -> `-0.48` shoulder aim), kept `RightHand` neutral to prevent wrist mesh twisting, and lowered `LeftUpperArm` (`Z = -0.62`) for natural athletic stance.

## [2026-11-14 08:35] Desktop Launcher Shortcut
- **Created `C:\Users\thiag\Desktop\Iniciar Isabela 3D.bat` (new file, nothing removed)**:
  - Added ASCII/CRLF batch launcher verifying `D:\Godot\Godot_v4.7.2-stable_win64.exe`, `D:\Godot\isabela_scene_test\project.godot`, and `D:\Godot\isabela_scene_test\scenes\game\playable_arena.tscn` before invoking Godot 4.7.2 directly into `res://scenes/game/playable_arena.tscn` via `--path` and `--scene`, so double-clicking starts the wave-survival game without modifying `run/main_scene` in `project.godot`.

## [2026-11-14 09:25] Fase 8 TPS Animation Library & FPS Viewmodel Arms
- **Backup created**: `D:\Godot\isabela_scene_test\.backups\CHANGELOG.md.20261114_092448.bak` before appending entry (`SK_Isabela.glb`, `main_isabela_scene.tscn`, `.gd`, and `data/game_balance.json` untouched).
- **Created `D:\Godot\isabela_scene_test\blend_sources\fase8_isabela_animations.blend` & `D:\Godot\isabela_scene_test\assets\SK_Isabela\SK_Isabela_Anims.glb` (`4,760,108` bytes)**:
  - Retargeted 16 UAL clips (`Idle_Loop`, `Walk_Loop`, `Jog_Fwd_Loop`, `Sprint_Loop`, `Crouch_Idle_Loop`, `Jump_Start`, `Jump_Loop`, `Jump_Land`, `Roll`, `Pistol_Idle_Loop`, `Pistol_Shoot`, `Pistol_Reload`, `Sword_Idle`, `Sword_Attack`, `Hit_Chest`, `Death01`) via exact world-basis A-pose -> T-pose quaternion conversion onto untouched 84-bone `Armature_Isabela` (`Max bone rest origin diff: 0.0` vs `SK_Isabela.glb`, verified in Godot 4.7.2 `--headless`).
  - Authored 12 combat clips (`Rifle_Idle_Loop`, `Rifle_Shoot`, `Rifle_Reload`, `Rocket_Idle_Loop`, `Rocket_Shoot`, `Rocket_Reload`, `Katana_Combo_1..3`, `Saber_Combo_1..3`) plus 3 additive/layer finger-grip tracks (`Grip_RightHand`, `Grip_LeftHand`, `Grip_BothHands`) using rigid shared-pivot curl matching `SK_Isabela_Body` skinning; left `Hair_*`, `Jaw`, `LeftEye`, `RightEye` unkeyed so Godot `SpringBoneSimulator3D` and facial tracks compose cleanly. Added microscopic `0.0002m` `Armature_SkinProxy` (`export_skins=True, export_materials='NONE'`) so Godot generates `Skeleton3D` tracks (`Armature_Isabela/Skeleton3D:*`).
- **Created `D:\Godot\isabela_scene_test\blend_sources\fase8_fps_arms.blend` & `D:\Godot\isabela_scene_test\assets\SK_Isabela\FPS_Arms.glb` (`12,895,116` bytes)**:
  - Extracted dedicated 1st-person arms + red vinyl sleeves (`FPS_Arms_Skin`, `FPS_Arms_Sleeves`) with planar bicep bisects and smooth topological 5-finger per-hand rigging (39 bones, `FPS_Root` + `Left/RightShoulder..Hand` + 30 finger bones, 55% forearm pronation twist distribution, opaque PBR materials), oriented in Godot `-Z` forward with `BoneAttachment3D("RightHand")/FPSWeaponSocket` (`world pos=(0.0917, -0.1111, -0.3655)`, `fwd=-Z`).
  - Baked 9 FPS NLA tracks at 24 FPS: `FPS_Idle` (2.0s), `FPS_Walk` (1.0s), `FPS_Fire_Pistol` (0.333s), `FPS_Fire_Heavy` (0.583s), `FPS_Reload` (1.5s), `FPS_Melee_1` (0.583s), `FPS_Melee_2` (0.583s), `FPS_Melee_3` (0.833s), `FPS_Draw` (0.5s).
- **Verified**: Cycles multi-pose inspection renders `tps_anims_sheet.png` and `fps_arms_preview.png` inspected visually + Godot 4.7.2 headless `GLTFDocument` check (`GODOT_GLB_VERIFY=PASS`).

## [2026-11-14 09:38] Fase 8 V2 — Closer TPS Camera, Retargeted SK_Isabela Animations, Finger Grips & Seamless TPS/FPS Toggle
- **Backups created**: `D:\Godot\isabela_scene_test\.backups\20261114_085506\`, `20261114_093000\`, and `20261114_093700\` prior to file edits (`SK_Isabela.glb` and `scenes/main_isabela_scene.tscn` left strictly untouched).
- **`data/game_balance.json`**:
  - Replaced distant Phase 7 `player.camera` values (`pivot_height_m=1.52`, `shoulder_offset_m=[0.52,0.14,0.0]`, `spring_length_normal_m=2.75`, `spring_length_aim_m=1.80`, `fov_normal_deg=64.0`, `fov_aim_deg=50.0`, `pitch_min_deg=-48.0`, `pitch_max_deg=42.0`) with tighter over-the-shoulder TPS framing (`pivot_height_m=1.30`, `shoulder_offset_m=[0.40,0.08,0.0]`, `spring_length_normal_m=1.80`, `spring_length_aim_m=1.18`, `fov_normal_deg=66.0`, `fov_aim_deg=50.0`, `pitch_min_deg=-58.0`, `pitch_max_deg=50.0`) and added FPS view settings (`fps_eye_height_m=1.58`, `fps_fov_normal_deg=86.0`, `fps_fov_aim_deg=66.0`, `fps_pitch_min_deg=-82.0`, `fps_pitch_max_deg=82.0`).
- **`scenes/game/player_isabela.tscn`**:
  - Updated `CameraPivot` Y `1.52 -> 1.3`, `SpringArm3D` offset `(0.52, 0.14, 0) -> (0.4, 0.08, 0)` and `spring_length` `2.75 -> 1.8`, `Camera3D` `fov=66.0`, `near=0.03`.
  - Updated `RightHandAttachment/WeaponSocket` transform (`position=(-0.015, 0.085, 0.015), rotation=(1.096067, 2.06996, 0.912807)` -> `position=(0.012, 0.068, 0.01), rotation=(1.35, 0.54, -0.26)`) verified against Forward+ renders for retargeted Pistol, Shotgun, and Katana grip alignment.
- **`scripts/game/input_setup.gd`**:
  - Added `toggle_view` (`KEY_V`) and `toggle_fps_centered` (`KEY_H`) input action registration in `ensure_default_actions()`.
- **`scripts/game/anim_library_loader.gd` (`207` lines) & `scripts/game/player_animator.gd` (`292` lines)**:
  - Replaced procedural-only animator with runtime loader (`load_clips_into_player` + `setup_isabela_anim_tree`) importing all 31 clips from `res://assets/SK_Isabela/SK_Isabela_Anims.glb`, setting `LOOP_LINEAR` on cyclic clips (`Idle`, `Walk`, `Jog_Fwd`, `Sprint`, `Crouch_Idle`, `Jump`, `Pistol_Idle`, `Rifle_Idle`, `Rocket_Idle`, `Sword_Idle`), and stripping `Hair_`/`LeftEye`/`RightEye` tracks to preserve `SpringBoneSimulator3D` hair physics and ARKit blink/focus/wince blendshapes.
  - Built layered `AnimationNodeBlendTree` combining `Loco` (`idle/walk/jog/sprint/jump_start/jump_loop/jump_land/roll/hit/death`), bone-filtered `UpperBlend` (`UpperIdle` + `UpperAction` OneShot for Pistol/Rifle/Rocket/Katana 1-3/Lightsaber 1-3), and finger-filtered `GripBlend` (`GripChoice` switching `Grip_RightHand` vs `Grip_BothHands`), plus additive strafe/pitch torso twist and `set_first_person_shadow_only()`.
- **`scripts/game/fps_viewmodel.gd` (`241` lines) & `scripts/game/player_camera_rig.gd` (`162` lines)**:
  - Created `FPSViewmodel` mounting `res://assets/SK_Isabela/FPS_Arms.glb` and active `SM_Weapon_*` under `Camera3D`, setting `LOOP_LINEAR` on `FPS_Idle`/`FPS_Walk`, disabling shadows on viewmodel meshes, and driving mouse inertia sway, idle/move bob, per-weapon hip/ADS/Doom-centered offsets, recoil, reload dips, and 3-step FPS melee slashes.
  - Added seamless TPS <-> FPS toggling (`toggle_view_mode`, `sync_player_view`, FPS eye height/FOV/pitch clamp, and center-screen aim ray with `min_dist=0.35`).
- **`scripts/game/weapon_vfx.gd` (`107` lines) & `scripts/game/weapon_manager.gd` (`285` lines)**:
  - Extracted `WeaponVFX` (`107` lines) with directional crescent `spawn_blade_trail()` meshes for Katana/Lightsaber 3-hit combos; wired `WeaponManager` to source FPS muzzle FX from `FPSViewmodel.get_muzzle_world_position()`, keep exact center-screen FPS raycast accuracy, and set `SHADOWS_ONLY` on TPS weapon visuals in FPS mode.
- **`scripts/game/hud_crosshair.gd` (`131` lines), `scripts/game/hud_controller.gd` (`291` lines), `scripts/game/player_combat_helper.gd` (`99` lines), `scripts/game/player_controller.gd` (`289` lines)**:
  - Extracted `HUDCrosshair` + dynamic crosshair/hitmarker + `[V] Visão: 3ª Pessoa / 1ª Pessoa (FPS)` indicator (`get_view_mode_text()`).
  - Extracted `PlayerCombatHelper` to keep `player_controller.gd` under `300` lines; wired `[V]`/`[H]`, `view_mode_changed`, animator combat triggers, and strafe input forwarding.
- **`tests/test_v2_camera_anims_fps.gd` & `manifest.json`**:
  - Added automated headless suite testing camera distances, `[V]`/`[H]` inputs, TPS<->FPS toggle + `SHADOWS_ONLY` + `FPSViewmodel` + muzzle origin + Doom offset + HUD indicator, plus all 31 `SK_Isabela_Anims.glb` clips, loop modes, hair track stripping, `AnimationTree` states, and all 9 `FPS_Arms.glb` clips. Updated `manifest.json` with `SK_Isabela_Anims`, `FPS_Arms`, and V2 validation renders.
  - Verified `--headless --import` (`exit 0`), `main_isabela_scene.tscn --quit` (`exit 0`), `playable_arena.tscn --quit` (`exit 0`), all 22 `scripts/game/*.gd` `< 300` lines (`max = 293`), and all 7 headless test suites (`exit 0`).

## [2026-11-14 17:52] Full Gamepad / Controller Support & Upgrade Modal Focus Navigation
- **Backups created**: `D:\Godot\isabela_scene_test\.backups\game_balance.json.20261114_174507.bak`, `input_setup.gd.20261114_174507.bak`, `player_camera_rig.gd.20261114_174507.bak`, `upgrade_modal_ui.gd.20261114_174507.bak`, `hud_controller.gd.20261114_174507.bak`, and `CHANGELOG.md.20261114_175147.bak` prior to edits (`SK_Isabela.glb` and `scenes/main_isabela_scene.tscn` left strictly untouched).
- **`data/game_balance.json`**:
  - Added `"controller_sensitivity": 3.4` and `"controller_aim_sensitivity_multiplier": 0.65` under `"player"."camera"` to allow smooth proportional analog stick camera rotation and ADS fine-aim dampening.
- **`scripts/game/input_setup.gd`**:
  - Extended idempotent `ensure_default_actions()`:
    - Registered analog look axes: `look_left`/`look_right` (`JOY_AXIS_RIGHT_X`), `look_up`/`look_down` (`JOY_AXIS_RIGHT_Y`).
    - Registered analog movement & D-pad: `move_left`/`move_right` (`JOY_AXIS_LEFT_X`, `JOY_BUTTON_DPAD_LEFT`, `JOY_BUTTON_DPAD_RIGHT`), `move_forward`/`move_back` (`JOY_AXIS_LEFT_Y`, `JOY_BUTTON_DPAD_UP`, `JOY_BUTTON_DPAD_DOWN`).
    - Registered action buttons: `fire` (RT `JOY_AXIS_TRIGGER_RIGHT`), `aim` (LT `JOY_AXIS_TRIGGER_LEFT`), `jump` (A `JOY_BUTTON_A`), `dash` (B `JOY_BUTTON_B`), `reload` (X `JOY_BUTTON_X`), `toggle_view` (Y `JOY_BUTTON_Y`), `sprint` (L3 `JOY_BUTTON_LEFT_STICK`), `toggle_fps_centered` (R3 `JOY_BUTTON_RIGHT_STICK`), `pause_game` (Start `JOY_BUTTON_START`), `prev_weapon` (LB `JOY_BUTTON_LEFT_SHOULDER`), `next_weapon` (RB `JOY_BUTTON_RIGHT_SHOULDER`).
    - Registered Upgrade Modal card selection shortcuts: `upgrade_select_1` (`JOY_BUTTON_X`, `JOY_BUTTON_DPAD_LEFT`), `upgrade_select_2` (`JOY_BUTTON_Y`, `JOY_BUTTON_DPAD_UP`), `upgrade_select_3` (`JOY_BUTTON_B`, `JOY_BUTTON_DPAD_RIGHT`).
- **`scripts/game/player_camera_rig.gd`**:
  - Added `apply_controller_look(look_vec: Vector2, delta: float, is_aiming: bool)` scaling look vector by `controller_sensitivity * (controller_aim_sensitivity_multiplier if is_aiming else 1.0) * delta` and updating `yaw_rad` / `pitch_rad`.
  - Added analog right-stick polling in `update_rig()` via `Input.get_vector("look_left", "look_right", "look_up", "look_down")` with automatic deadzone processing.
- **`scripts/game/upgrade_modal_ui.gd`**:
  - Configured card buttons with `FOCUS_ALL`, neighbouring navigation shortcuts (`focus_neighbor_left`/`right`), and gold highlight border (`focus_style`).
  - Added automatic focus grabbing `_buttons[0].grab_focus()` when modal opens (`if is_inside_tree()`).
  - Added controller shortcut badges on cards (`[1/X]`, `[2/Y]`, `[3/B]`) and controller button listeners in `_unhandled_input()` with safe `get_viewport()` null-guards.
- **`scripts/game/hud_controller.gd`**:
  - Wired `_pause_btn.grab_focus()` when pausing or entering game over state so gamepads can select "REINICIAR PARTIDA" immediately via `JOY_BUTTON_A` (`ui_accept`).
- **`tests/test_gamepad_support.gd` (new, 140 lines)**:
  - Created automated test suite verifying Joypad action bindings, analog stick look integration, upgrade modal button focus / D-pad / shortcut navigation, and pause menu focus.
- **Verification**:
  - All 8 headless test suites (`test_balance_and_upgrades`, `test_combat_core`, `test_player_enemy_weapons`, `test_spawner_projectiles_pickups`, `test_hud_and_arena_loop`, `test_playable_arena_e2e`, `test_v2_camera_anims_fps`, `test_gamepad_support`) passed (`exit 0`).
  - All 22 scripts in `scripts/game/` confirmed strictly `< 300` lines (range 64 to 250 lines).

## [2026-11-15 17:16] Correção de Poke-Through na Jaqueta, Alinhamento de Grip das Armas, SMG Automática (Slot 7) e Assets2Godot
- **Backups created**: `D:\Godot\isabela_scene_test\.backups\*` (`20261115_165827`, `20261115_170706`, `20261115_171403` cobrindo `project.godot`, `player_isabela.tscn`, `game_balance.json`, `balance_db.gd`, `weapon_loadout.gd`, `hud_weapon_bar.gd`, `input_setup.gd`, `player_combat_helper.gd`, `player_animator.gd`, `fps_viewmodel.gd`, `test_balance_and_upgrades.gd`, `test_hud_and_arena_loop.gd`, `test_jacket_and_weapon_grip.gd`, `CHANGELOG.md`). `SK_Isabela.glb` e `scenes/main_isabela_scene.tscn` mantidos intactos.
- **Correção da jaqueta nas costas (`SK_Isabela_Top`) e grip das armas (TPS/FPS)**:
  - Removido/substituído offset antigo do `WeaponSocket` (`Vector3(-0.068, 0.178, 0.032)` -> `Vector3(-0.120, 0.162, 0.098)` -> calibrado para `Vector3(-0.096, 0.064, 0.100)`) em `scenes/game/player_isabela.tscn` (linha 95) e no fallback de `scripts/game/player_animator.gd` (linha 61), posicionando o encaixe diretamente no centróide real dos vértices esfolados da palma e dedos (`RightHand`, `RightThumbDistal`, `RightIndexDistal`, `RightMiddleDistal`) em espaço local de `RightHandAttachment` (eliminando o afastamento de ~10 cm visível antes).
  - Atualizado `data/game_balance.json` para `lightsaber` e `katana` com `"tps_grip_pos": [0.0, 0.0, 0.0]` e `"tps_grip_rot_deg": [-85.0, 0.0, 0.0]` para alinhar as lâminas para frente/fora na mão direita em 3ª pessoa, e `"fps_grip_rot_deg": [-15.0, 0.0, 0.0]`.
  - Validado visualmente nas prévias de jog, TPS (`pistol`, `smg`, `katana`, `lightsaber`) e FPS (`smg`, `katana`, `lightsaber`).
- **Nova arma: SMG Automática (`SM_Weapon_SMG`, Slot 7)**:
  - Asset obtido via API pública do BlendKit (`SMG Sci Fi submachine gun concept`, licença `royalty_free`, formato `gltf_godot`), normalizado no Blender 5.2 para `assets/SM_Weapon_SMG/SM_Weapon_SMG.glb` (pivô no grip `(0,0,0)`, cano apontado em `-Z`, topo em `+Y`, nó `Muzzle` adicionado, texturas reduzidas para `<= 1024px`, malha otimizada de `128.568` para `62.335` vértices) e importado no Godot 4.7.2.
  - Adicionado Slot `7` `"id": "smg"` (`"SMG Automática"`, `"fire_mode": "auto"`, `14.0` de dano, `12.5 Hz` / 750 RPM, carregador `36`, reserva `216`/`360`, recarga `1.45s`) em `data/game_balance.json`.
  - Atualizado `scripts/game/balance_db.gd` (`_weapons_by_slot.size() >= 6`), `scripts/game/input_setup.gd` (`weapon_1`..`weapon_7`), `scripts/game/weapon_loadout.gd` (`cycle_slot` usando `maxi(1, _slots.size())`), `scripts/game/player_combat_helper.gd` (`range(1, 8)`), `scripts/game/hud_weapon_bar.gd` (7 slots em `114x56`), `scripts/game/player_animator.gd` (`"smg"` em `rifle_shoot`, `rifle_reload` e `UpperIdle="rifle"` / `GripChoice="both"`) e `scripts/game/fps_viewmodel.gd` (`WEAPON_TWEAKS["smg"]` + `FPS_Fire_Heavy`).
- **Plugin `Assets2Godot` (`D:\Godot\addons\assets2godot` -> `res://addons/assets2godot`)**:
  - Copiado `Assets2Godot v0.8.2` de `D:\Godot\addons\assets2godot` para `D:\Godot\isabela_scene_test\addons\assets2godot` e habilitado em `project.godot` sob `[editor_plugins] enabled=PackedStringArray("res://addons/assets2godot/plugin.cfg")`.
- **Verificação**:
  - Atualizados `tests/test_balance_and_upgrades.gd`, `tests/test_hud_and_arena_loop.gd` e `tests/test_jacket_and_weapon_grip.gd` (com medição real do centróide esfolado da mão direita e wrap `7 -> 1`).
  - Todas as **9 suítes headless** passaram com `EXIT=0` (`ALL_TESTS_PASSED`).
  - Todos os **22 scripts** em `scripts/game/*.gd` verificados abaixo de 300 linhas (máximo `299` em `player_animator.gd`).

## [2026-11-15 17:34] Preparação de Documentação, Contexto para Agentes e Publicação no GitHub
- **Arquivos criados**:
  - `.gitignore`: ignora cache `.godot/`, `.backups/`, backups do Blender (`*.blend1`, `*.blend2`, `*.blend@`), executáveis baixados pelo `Assets2Godot` (`addons/assets2godot/client/**`), `.venv/` e metadados locais de SO/IDE (preservando `*.import` e `*.uid`).
  - `.gitattributes`: normaliza fins de linha de recursos texto do Godot e configura **Git LFS** para `*.blend` (necessário para `blend_sources/fase6_validation_scene.blend`, ~117,5 MB).
  - `README.md`: documentação para colaboradores com visão geral do jogo, tabela do arsenal (7 armas), requisitos passo-a-passo (Git + Git LFS, Godot `4.7.2-stable`, Blender `5.2+` opcional, `Assets2Godot v0.8.2`), controles completos (Teclado/Mouse e Gamepad), comandos para as 9 suítes de testes headless e regras de contribuição.
  - `GEMINI.md`: guia de contexto técnico para agentes de IA com arquitetura modular dos 22 scripts em `scripts/game/`, invariantes (`< 300` linhas/script, proteção de `SK_Isabela.glb` e `main_isabela_scene.tscn`), armadilhas resolvidas (`WeaponSocket`, `SceneTree.quit`, facing `+Z`/`-Z`) e protocolo obrigatório de verificação.
- **Publicação Git / GitHub**: repositório `floodnet666/isabela-3d-survival` inicializado em `main` com Git LFS para `*.blend` e enviado ao GitHub (`public`).

## [2026-11-15 17:49] Correção de Pausa (Esc) — Congelamento de Inimigos, Projéteis e Spawner
- **Backups criados**: `D:\Godot\isabela_scene_test\.backups\arena_coordinator.gd.20261115_*.bak`, `test_hud_and_arena_loop.gd.20261115_*.bak`, `CHANGELOG.md.20261115_*.bak`.
- **`scripts/game/arena_coordinator.gd` (linha 26)**:
  - **Removido**: `process_mode = Node.PROCESS_MODE_ALWAYS`
  - **Adicionado**: `process_mode = Node.PROCESS_MODE_PAUSABLE`
  - **Motivo**: como `PlayableArena` é o nó raiz da cena, `PROCESS_MODE_ALWAYS` fazia todos os filhos com `INHERIT` (`Entities`, `EnemyDroid`, `WaveSpawner`, `ProjectileController`, `PickupCrate`, `Player`, `SM_Ship`) continuarem processando e atacando mesmo com `get_tree().paused = true`. `HUD` (`hud_controller.gd`) e `UpgradeModalUI` (`upgrade_modal_ui.gd`) já definem `PROCESS_MODE_ALWAYS` explicitamente e continuam recebendo `Esc`/`Start` e cliques normalmente.
- **`tests/test_hud_and_arena_loop.gd`**:
  - Adicionado teste de regressão `_test_pause_freezes_enemies_and_spawner()` simulando `pause` (`Esc`) com inimigo a `1,0 m` do jogador durante 35 frames de física (verificando zero dano/movimento em pausa, `HUD` processável e retomada limpa no segundo `Esc`).
- **Verificação**:
  - Todas as **9 suítes headless** passaram com `EXIT=0` (`ALL_9_TESTS_PASSED`).
  - `scripts/game/*.gd` mantidos abaixo de 300 linhas (`arena_coordinator.gd` com 203 linhas).

## [2026-11-15 17:57] Workflow CI no GitHub Actions (`.github/workflows/godot-tests.yml`)
- **Backup criado**: `D:\Godot\isabela_scene_test\.backups\CHANGELOG.md.20261115_175716.bak`.
- **Adicionado [`.github/workflows/godot-tests.yml`](file:///D:/Godot/isabela_scene_test/.github/workflows/godot-tests.yml)**:
  - **Triggers**: `pull_request` (`branches: [main]`), `push` (`branches: [main]`) e `workflow_dispatch`, com `concurrency` cancelando execuções anteriores no mesmo ref.
  - **Checkout enxuto**: `actions/checkout@v4` com `lfs: false` para não baixar os `.blend` de `blend_sources/` via Git LFS no CI.
  - **Trava `< 300` linhas**: verifica cada arquivo em `scripts/game/*.gd` via `wc -l`, emitindo erro `::error file=...::` se atingir `>= 300` linhas.
  - **Godot `4.7.2-stable` Linux headless + cache**: faz cache do binário `Godot_v4.7.2-stable_linux.x86_64` em `~/.cache/godot/4.7.2-stable` e de `.godot/imported`, executa `--headless --path . --import` (`timeout 180s`) e roda sequencialmente todas as suítes `tests/test_*.gd` (`timeout 120s` por suíte).

## [2026-11-15 18:45] Trilha A — Mood Sci-Fi Crepúsculo, Desmontagem Física, Props & Áudio Punk-Rock
- **Backups criados**: `D:\Godot\isabela_scene_test\.backups\*.20261115_181033.bak` (`arena_coordinator.gd`, `CHANGELOG.md`, `enemy_droid.gd`, `playable_arena.tscn`, `player_combat_helper.gd`, `player_controller.gd`, `projectile_controller.gd`, `wave_spawner.gd`, `weapon_manager.gd`, `weapon_vfx.gd`).
- **Mood Sci-Fi & Cenário**:
  - [`scenes/game/playable_arena.tscn`](file:///D:/Godot/isabela_scene_test/scenes/game/playable_arena.tscn): ajustado `ProceduralSkyMaterial_1`, `Environment_1` (`glow_intensity = 0.72`, `fog_light_color` azul-petróleo) e `DirectionalLight3D` para estética **Sci-Fi Crepúsculo / Neon Industrial**.
  - Adicionado [`scripts/game/arena_props.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/arena_props.gd): 4 barreiras baixas e 5 blocos/estruturas táticas (`StaticBody3D`, layer `1`), 4 torres de comunicação neon (`OmniLight3D`), capacetes `SM_Helmet_A`/`SM_Helmet_B` como detalhes de destroços e 6 barris explosivos táticos, preservando raio livre `>= 4 m` no spawn.
  - Adicionado [`scripts/game/explosive_barrel.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/explosive_barrel.gd): células/barris de plasma destrutíveis com AoE (`6.0 m`), reação em cadeia (`5.5 m`) e respawn periódico.
  - [`scripts/game/wave_spawner.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/wave_spawner.gd): atualizado `setup(...)` e seleção de spawn/caixas para respeitar `ArenaProps.is_position_clear()`.
- **Destruição dos Robôs & VFX (Opções 3 e 4)**:
  - Adicionado [`scripts/game/droid_destruction_vfx.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/droid_destruction_vfx.gd): explosão aditiva + onda de faíscas + marca temporária de queimadura + `6–8` peças físicas `RigidBody3D` (`droid_debris`) quicando no piso com teto global de `36` peças e fade-out.
  - [`scripts/game/enemy_droid.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/enemy_droid.gd): ativado overlay real de hit-flash em dano/crítico e chamada a `DroidDestructionVFX` antes de `queue_free()`.
  - [`scripts/game/weapon_vfx.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/weapon_vfx.gd): adicionado `spawn_hit_sparks()`, muzzle flash emissivo 3D e rastro duplo + faíscas para Katana e Sabre de Luz.
  - [`scripts/game/weapon_manager.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/weapon_manager.gd) & [`scripts/game/projectile_controller.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/projectile_controller.gd): suporte a `damageable_props` (barris), unificação em `_apply_ray_hit`, sinal `shot_executed` e faíscas de impacto.
- **Áudio Híbrido Punk-Rock + SFX**:
  - Adicionados [`scripts/game/audio_manager.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/audio_manager.gd), [`scripts/game/procedural_sfx.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/procedural_sfx.gd) e `assets/audio/music/punk_rock_loop.ogg` + `15` efeitos `.ogg` em `assets/audio/sfx/`, com fallback procedural em `AudioStreamWAV`, buses `Music`/`SFX` e ducking de pausa.
  - [`scripts/game/arena_coordinator.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/arena_coordinator.gd) & [`scripts/game/player_combat_helper.gd`](file:///D:/Godot/isabela_scene_test/scripts/game/player_combat_helper.gd): ligados todos os eventos sonoros de tiro, corte, recarga, acerto, explosões, coleta, level-up, onda e pausa.
- **Testes**:
  - Adicionada suíte [`tests/test_trilha_a_audio_and_destruction.gd`](file:///D:/Godot/isabela_scene_test/tests/test_trilha_a_audio_and_destruction.gd); todas as **10 suítes headless** passaram (`TOTAL_FAILED=0`) e todos os `scripts/game/*.gd` estão `< 300` linhas (máximo `299` em `player_animator.gd`, `295` em `weapon_manager.gd`).

## [2026-11-15 15:40] Ponto 2 — Interface, Menus & UX (Menu Duna Sci-Fi, Configurações, Pausa & Game Over Roguelite)
- **Backups criados**: `.backups/20261115_153154/` (`hud_controller.gd`, `game_manager.gd`, `arena_coordinator.gd`, `player_camera_rig.gd`, `weapon_manager.gd`, `audio_manager.gd`, `enemy_droid.gd`, `CHANGELOG.md`).
- **Menu Principal Estilo Duna**:
  - Criados [`scenes/game/main_menu.tscn`](file:///c:/Users/sphok/isabela-3d-survival/scenes/game/main_menu.tscn), [`scripts/game/main_menu_controller.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/main_menu_controller.gd) e [`scripts/game/dune_backdrop.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/dune_backdrop.gd): atmosfera desértica crepuscular com silhuetas de dunas, nave orbital e partículas de poeira/especiaria, botões `INICIAR MISSÃO`, `CONFIGURAÇÕES`, `COMO JOGAR & CONTROLES` e `SAIR`, com navegação completa por Teclado/Gamepad e trilha sonora.
- **Sistema de Configurações & Persistência**:
  - Criados [`scripts/game/settings_manager.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/settings_manager.gd) e [`scripts/game/settings_modal_ui.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/settings_modal_ui.gd): persistência em `user://settings.cfg` com abas `ÁUDIO` (Master, Música, SFX), `VÍDEO` (Tela Cheia, V-Sync, FOV) e `CONTROLES` (Sensibilidade Mouse/Gamepad, modo padrão FPS), com alternância de abas via `LB`/`RB`.
  - Integrado suporte em [`scripts/game/audio_manager.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/audio_manager.gd) e [`scripts/game/player_camera_rig.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/player_camera_rig.gd).
- **Menu de Pausa Completo & Game Over Roguelite**:
  - Criados [`scripts/game/pause_modal_ui.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/pause_modal_ui.gd) e [`scripts/game/game_over_modal_ui.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/game_over_modal_ui.gd), integrados em [`scripts/game/hud_controller.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/hud_controller.gd).
  - Atualizados [`scripts/game/game_manager.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/game_manager.gd), [`scripts/game/enemy_droid.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/enemy_droid.gd) e [`scripts/game/arena_coordinator.gd`](file:///c:/Users/sphok/isabela-3d-survival/scripts/game/arena_coordinator.gd) para rastrear dano total por arma, abates por tipo, tempo de corrida e retornar ao `main_menu.tscn`.
- **Verificação**:
  - Criada suíte [`tests/test_menus_and_settings.gd`](file:///c:/Users/sphok/isabela-3d-survival/tests/test_menus_and_settings.gd); todas as **11 suítes headless** passaram (`ALL_11_TESTS_PASSED`) e todos os scripts em `scripts/game/*.gd` estão estritamente abaixo de 300 linhas.

