# Projeto Isabela 3D — Wave Survival Action Game

Jogo de ação e sobrevivência em ondas 3D desenvolvido em **Godot Engine `4.7.2-stable` (`Forward+`)**, com alternância instantânea entre **3ª Pessoa (TPS)** e **1ª Pessoa (FPS)**, suporte completo a **Teclado + Mouse** e **Controle (Gamepad)**, 7 armas distintas e progressão roguelite por cartas de upgrade.

---

## Visão Geral do Gameplay
- **Arena Multi-Bioma Procedural (WFC + 5 Mundos):** A cada **5 ondas**, a nave-mãe `SM_Ship` desce e teletransporta a jogadora com um raio trator entre **5 biomas sorteados aleatoriamente** (`Costa Espelhada`, `Dunas da Pirâmide Solar`, `Interior da Nave-Mãe`, `Geleira Criogênica` e `Caldeira Vulcânica Obsidiana`), com ciclo Dia/Noite (`1 min = 2h`), shaders `Forward+`, clima atmosférico e elevadores móveis.
- **Inimigos com IK (`TwoBoneIK3D`):**
  - **Droide Batedor (`SK_Droid_Small`):** Ágil corpo a corpo.
  - **Droide Sentinela (`SK_Droid_Tall`):** Blindado, introduzido na Onda 2, dispara projéteis de plasma defletíveis pelo Sabre de Luz e executa ataque pesado em curta distância.
- **Sistema de Ondas, XP e Upgrades:** Derrotar droides concede XP e chance de cair caixas de Vida (`SM_Crate_Health`) e Munição (`SM_Crate_Ammo`). Ao subir de nível ou concluir uma onda, abre-se o modal de **3 cartas aleatórias** em 4 raridades (`Comum`, `Raro`, `Épico`, `Lendário`).

### Arsenal (7 Armas)
| Slot | Arma | Modo / Tipo | Dano Base | Cadência | Recurso | Destaque |
|---:|---|---|---:|---:|---|---|
| `1` | Pistola Tática (`pistol`) | Semi-auto Hitscan | `22.0` (`1.6×` head) | `4.5 Hz` | `15` / `180` | Sidearm precisa e rápida |
| `2` | Sabre de Luz (`lightsaber`) | Combo Melee (`135°`) | `48.0` | `2.1 Hz` | Ilimitado | Deflete plasma inimigo (`1.75×`) + `+5%` vel. |
| `3` | Escopeta Tática (`shotgun`) | 8 projéteis Hitscan | `15.5 × 8` | `1.25 Hz` | `6` / `36` | Forte recuo/knockback (`10.5 m/s`) |
| `4` | Lança-Foguetes (`rocket_launcher`) | Projétil Explosivo | `30` + `135` AoE | `0.65 Hz` | `2` / `10` | Dano em área (`4.8m` de raio) |
| `5` | Katana Térmica (`katana`) | Combo Melee (`95°`) | `36.0` | `3.1 Hz` | Ilimitado | Alto crítico (`28% / 2.1×`) + perfura armadura + lunge |
| `6` | Rifle Laser (`laser_gun`) | Feixe Perfurante (`3` alvos) | `13.5` (`1.4×` head) | `10.0 Hz` | Bateria `100` | Sem munição finita; ventila manualmente (`R` / `X`) |
| `7` | SMG Automática (`smg`) | Automática Hitscan | `14.0` (`1.45×` head) | `12.5 Hz` | `36` / `216` | Fogo contínuo de alta cadência (`750 RPM`) |

---

## Requisitos Passo-a-Passo para Colaboradores

### 1. Pré-requisitos obrigatórios
1. **Git + Git LFS**
   - Os arquivos-fonte do Blender em `blend_sources/*.blend` (incluindo `fase6_validation_scene.blend`, ~117 MB) usam **Git LFS**.
   - Instale o [Git](https://git-scm.com/) e o [Git LFS](https://git-lfs.com/) **antes** de clonar:
     ```bash
     git lfs install
     git clone https://github.com/floodnet666/isabela-3d-survival.git
     cd isabela-3d-survival
     git lfs pull
     ```
2. **Godot Engine `4.7.2-stable` (versão padrão / GDScript)**
   - Baixe a versão `4.7.2-stable` compatível com **Forward+** no site oficial da [Godot Engine](https://godotengine.org/download/).
   - *Importante:* A primeira abertura do projeto criará a pasta local `.godot/` com o cache de importação (isso pode levar alguns segundos/minutos na primeira vez). **Não** adicione `.godot/` ao Git; mantenha os arquivos `*.import` e `*.uid` versionados.

### 2. Pré-requisitos opcionais (dependendo da sua área)
- **Blender `5.2+` (Artistas 3D / Animação):** Necessário apenas para editar os fontes em `blend_sources/*.blend` e re-exportar `.glb` para `assets/`.
  - Regra de exportação: formato `.glb` com **+Y Up**, frente da arma no Blender **`+Y`** (-> Godot `-Z`), topo **`+Z`** (-> Godot `+Y`), pivô da empunhadura em `(0, 0, 0)`.
- **Addon `Assets2Godot v0.8.2` (incluso em `res://addons/assets2godot`):**
  - Já vem pré-instalado e habilitado em `project.godot` (licença GPLv2).
  - Dentro do Godot Editor, use a aba **Assets** para buscar modelos/texturas/HDRIs gratuitos (BlendKit, Polyhaven e ambientCG). Na primeira utilização de downloads completos, o plugin pode baixar localmente o cliente auxiliar `bk_client`.

---

## Como Rodar o Jogo
1. Abra o projeto (`project.godot`) no **Godot 4.7.2-stable**.
2. Pressione **`F5`** (*Play Project*, abre `main_menu.tscn` → `playable_arena.tscn`) ou abra `res://scenes/game/playable_arena.tscn` e pressione **`F6`** para ir direto à arena.

---

## Controles (Teclado + Mouse e Gamepad)

| Ação | Teclado / Mouse | Controle (Xbox / PlayStation) |
|---|---|---|
| Mover | `W A S D` / Setas | Analógico Esquerdo / D-Pad |
| Câmera / Mirar | Mouse | Analógico Direito |
| Atirar / Golpe Melee | `Botão Esquerdo (LMB)` ou `F` | `RT` (`R2`) ou `RB` (`R1`) |
| Mira Precisa (ADS) | `Botão Direito (RMB)` | `LT` (`L2`) |
| Pular | `Espaço` | `A` (`Cross`) |
| Correr (Sprint) | `Shift` | `L3` (clique no analógico esquerdo) |
| Dash Tático (iframes) | `Q` ou `Ctrl` | `B` (`Circle`) ou `LB` (`L1`) |
| Recarregar / Ventilar Laser | `R` | `X` (`Square`) |
| Selecionar Arma (1–7) | Teclas `1` a `7` | `—` |
| Próxima / Anterior Arma | `Roda do Mouse` | `RB`/`LB` (`R1`/`L1`) ou `D-Pad Esq/Dir` |
| Alternar Câmera TPS ↔ FPS | `V` | `Y` (`Triangle`) ou `Back/Select` |
| Câmera Doom Centralizada (FPS) | `H` | `R3` (clique no analógico direito) |
| Escolher Carta de Upgrade | Mouse ou teclas `1 / 2 / 3` | `X / Y / B` ou `D-Pad` |
| Pausar | `Esc` | `Start / Menu` |

---

## Como Rodar a Suíte de Testes (21 Suítes Headless)
Antes de enviar qualquer Pull Request, execute todas as suítes automatizadas via terminal (ajuste o caminho do executável Godot 4.7.2 para o seu sistema):

**Windows (PowerShell):**
```powershell
$godot = "D:\Godot\Godot_v4.7.2-stable_win64_console.exe"
Get-ChildItem tests\test_*.gd | Sort-Object Name | ForEach-Object {
    & $godot --headless --path . --script "res://tests/$($_.Name)"
    if ($LASTEXITCODE -ne 0) { throw "Falha em $($_.Name) (EXIT=$LASTEXITCODE)" }
}
Write-Host "ALL_TESTS_PASSED" -ForegroundColor Green
```

**Linux / macOS (Bash):**
```bash
GODOT=godot-4.7.2
for t in tests/test_*.gd; do
  echo "=== $t ==="
  "$GODOT" --headless --path . --script "res://$t" || exit 1
done
echo "ALL_TESTS_PASSED"
```

---

## Regras para Contribuidores e Agentes de IA
- **Modularidade:** Todo script em `scripts/game/*.gd` deve permanecer **estritamente abaixo de 300 linhas**.
- **Balanceamento centralizado:** Altere números de armas, ondas, inimigos e upgrades em `data/game_balance.json` ao invés de espalhar constantes pelo código.
- **Integridade de cenas base:** Não modifique `assets/SK_Isabela/SK_Isabela.glb`, `scenes/main_isabela_scene.tscn` ou `scenes/test_fase1..5_*.tscn`.
- **Uso com Agentes de IA:** Este repositório inclui o arquivo [`GEMINI.md`](GEMINI.md) na raiz com arquitetura detalhada, armadilhas já resolvidas e checklist de verificação automática para agentes.
- **Histórico & Documentação:** Consulte [`GAME_DESIGN.md`](GAME_DESIGN.md) para especificações de design/pipeline e [`CHANGELOG.md`](CHANGELOG.md) para o histórico cirúrgico das mudanças.
