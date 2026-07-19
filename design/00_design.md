# Hang Megiddo — Design

## Premise

Real-time 3D simulation of the **Battle of Megiddo**, c. **1457 BCE**.  
Player commands **Egypt under Thutmose III** after forcing the **Aruna pass**.  
AI commands the **Canaanite coalition** (Kadesh & allies) defending the plain and **Megiddo**.

## Pillars

1. **Touch-first** RTS (mouse emulates touch on desktop)  
2. **Fluid 3D** — steering movement, orbit camera, chariot shock  
3. **Egyptian visual language** — sand plain, gold/blue UI, limestone fortress  
4. **Readable history** — pass road, fortress objective, chariot weight  

## Systems

| System | Notes |
|--------|--------|
| Units | Spearman, archer, chariot, hero |
| Orders | Move, attack, attack-move, hold |
| Victory | Strength collapse · hold Megiddo · time score |
| AI | Screen plain, garrison city, counter-charge |

## Historical layout (v0.2)

| Zone | Role |
|------|------|
| **Aruna gorge (south)** | Narrow corridor; Egyptian column emerges |
| **Pass mouth** | Fan onto plain; Egyptian camp markers |
| **Plain of battle** | Chariot ground; Canaanite line faces south |
| **Megiddo tell (north)** | Steep mound, mudbrick walls, **south gate**, ramp |
| **Side roads** | Visual only — the routes Canaan expected |

### Phases
1. **Emerge** — Egypt auto-marches out of gorge; Canaan holds  
2. **Deploy** — Egyptian wings form (chariots flanks)  
3. **Battle** — free fight; hold gate approaches to win siege start  

### Related

Same studio stack as **Hang Calhoun** (Godot 4 GDScript), different genre presentation (3D RTS vs 2D operational wargame).
