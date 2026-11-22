"""
Convierte una construccion de un mundo de Minecraft (Anvil 1.16+) en un mundo de bloques de Galaxy 55 para la nave nodriza.
Uso: python -I port/tools/mc2g55.py <carpeta del mundo> <salida .bin>
     python -I port/tools/mc2g55.py --convert <mothership.bin G55M/G55N/G55O> <salida .bin>   (pasa un archivo de antes a G55P)

Salida 'G55P': ancho, largo, alto, aparicion x, y, z (uint16 LE); las bahias del hangar (numero y centro del suelo x, y, z); los
robots (numero y x, y, z, tipo: 0..3 = comerciante mirando a +x, +y, -x, -y; 4 = dron); la tabla de nombres de bloque (numero y
cada nombre: uint8 largo y ASCII, de BlockKind de src/G55/com/Common.hx; la primera BEmpty) y despues, comprimido con zlib, la
posicion en esa tabla de cada celda (uint16 LE) en orden z, y, x. Los ejes: x de Minecraft -> x, z de Minecraft -> y (invertido
para no reflejar la nave), altura -> z. Los formatos de antes (G55M sin bahias ni robots, G55N sin robots, G55O) guardaban el
numero de BlockKind en un byte por celda: un bloque con numero > 255 no cabia.
"""
import sys, os, re, zlib, struct, collections, array
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mcread

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..')

def kinds():
    s = open(os.path.join(ROOT, 'src/G55/com/Common.hx'), encoding='utf-8').read()
    m = re.search(r'enum BlockKind \{(.*?)\n\}', s, re.S).group(1)
    names = [l.strip().rstrip(';') for l in m.split('\n') if l.strip() and not l.strip().startswith('//')]
    return {n: i for i, n in enumerate(names)}

def write_g55p(out, W, L, H, spawn, bays, robots, grid, names):
    """escribe la nave en G55P (ver arriba); grid: numero de BlockKind de cada celda, names: nombre de cada numero"""
    table, at = ['BEmpty'], {0: 0}
    cells = array.array('H', [0]) * len(grid)
    for i, k in enumerate(grid):
        p = at.get(k)
        if p is None:
            p = at[k] = len(table)
            table.append(names[k])
        cells[i] = p
    if sys.byteorder == 'big': cells.byteswap()
    head = b'G55P' + struct.pack('<6H', W, L, H, *spawn) + struct.pack('<H', len(bays))
    for b in bays: head += struct.pack('<3H', *b)
    head += struct.pack('<H', len(robots))
    for r in robots: head += struct.pack('<4H', *r)
    head += struct.pack('<H', len(table))
    for n in table: head += bytes([len(n)]) + n.encode('ascii')
    open(out, 'wb').write(head + zlib.compress(cells.tobytes(), 9))
    return table

def convert(src, out):
    """un mothership.bin de antes (G55M, G55N o G55O: un byte por celda) a G55P, con los nombres de BlockKind de ahora"""
    b = open(src, 'rb').read()
    magic = b[:4]
    if magic not in (b'G55M', b'G55N', b'G55O'): sys.exit('no es un mothership.bin de antes: ' + repr(magic))
    W, L, H, sx, sy, sz = struct.unpack_from('<6H', b, 4)
    pos, bays, robots = 16, [], []
    if magic != b'G55M':
        n, = struct.unpack_from('<H', b, pos); pos += 2
        for i in range(n): bays.append(struct.unpack_from('<3H', b, pos)); pos += 6
    if magic == b'G55O':
        n, = struct.unpack_from('<H', b, pos); pos += 2
        for i in range(n): robots.append(struct.unpack_from('<4H', b, pos)); pos += 8
    grid = zlib.decompress(b[pos:])
    assert len(grid) == W * L * H, 'tamano de la rejilla'
    K = kinds()
    names = sorted(K, key=K.get)
    table = write_g55p(out, W, L, H, (sx, sy, sz), bays, robots, grid, names)
    print(magic.decode(), '->', 'G55P', 'medidas', W, L, H, 'bahias', len(bays), 'robots', len(robots), 'bloques distintos', len(table))

# tabla: (fragmento del nombre de Minecraft, bloque de Galaxy 55); la primera que coincide gana. None = se ignora (detalles).
RULES = [
    # detalles que no tienen equivalente (se quitan)
    ('trapdoor', None), ('button', None), ('pressure_plate', None), ('redstone_wire', None), ('lever', None),
    ('repeater', None), ('comparator', None), ('banner', None), ('_bed', None), ('ladder', None), ('sign', None),
    ('torch', None), ('rail', None), ('carpet', None), ('piston_head', None), ('piston', 'BMotherPanel'), ('command_block', None), ('dispenser', None),
    ('hopper', None), ('tripwire', None), ('note_block', None), ('player_head', None), ('barrier', None),
    ('daylight', None), ('sea_pickle', None), ('seagrass', None), ('grass', None) if False else ('tall_grass', None),
    ('vine', None), ('anvil', 'RAIL'), ('grindstone', 'RAIL'),   # los yunques son los railes del suelo (ver main) ('_door', None), ('fence_gate', None), ('lectern', None),
    ('campfire', None), ('chain', None), ('snow', None), ('slime', None), ('flower', None),
    # luces
    ('sea_lantern', 'BShedWallLight'), ('glowstone', 'BLamp'), ('redstone_lamp', 'BLamp'), ('lantern', 'BLamp'),
    ('end_rod', 'BLamp'), ('shroomlight', 'BLamp'),
    # cristal
    ('light_blue_stained_glass', 'BMotherField'), ('blue_stained_glass', 'BMotherField'),   # la pared de los hangares
    ('cyan_stained_glass', 'BMotherField'),   # ranuras que dan al espacio: tambien campo de fuerza (el cristal parecia un hueco)
    ('tinted_glass', 'BShipGlassBlack'), ('black_stained_glass', 'BShipGlassBlack'), ('glass', 'BGlass'),
    ('iron_bars', 'BIronFence'),
    # metal y piedra de la nave
    ('quartz', 'BShipHull'), ('iron_block', 'BShipHull'), ('white_concrete', 'BShipHull'),
    ('stone_brick', 'BMotherHull'), ('chiseled_stone', 'BMotherHull'),
    ('deepslate_tile', 'BMotherDark'), ('deepslate_brick', 'BMotherDark'), ('deepslate', 'BMotherDark'),
    ('blackstone', 'BMotherDark'), ('basalt', 'BMotherDark'), ('netherite', 'BShipTubes'), ('coal_block', 'BShipTubes'),
    ('gray_concrete', 'BShipWire'), ('gray_wool', 'BShipWire'), ('black_wool', 'BShipTubes'), ('redstone_block', 'BRawRed'),
    ('andesite', 'BMotherPanel'), ('smooth_stone', 'BMotherPanel'), ('cobble', 'BMotherDark'), ('stone', 'BMotherPanel'),
    # colores
    ('yellow_terracotta', 'BAutumnStraw'), ('light_blue_terracotta', 'BBlueCrystalDense'), ('blue_terracotta', 'BMarsBlueRock'),
    # naturaleza (jardines)
    ('water', 'BWater'), ('grass_block', 'BSoilCover'), ('rooted_dirt', 'BSoil'), ('dirt', 'BSoil'), ('sand', 'BMoonSand'),
    ('leaves', 'BGreenLeaves'), ('_log', 'BWood'), ('planks', 'BWoodPlank'), ('_slab', 'BWoodPlank'), ('_stairs', 'BWoodPlank'),
    ('barrel', 'BWoodPlank'), ('crafting_table', 'BWoodPlank'), ('furnace', 'BShipComputer'), ('smoker', 'BShipComputer'),
    ('chest', 'BChest'),
]

# de momento solo se visita el hangar: las puertas se dejan cerradas y tapadas (lo pidio el usuario). True = abrirlas.
OPEN_DOORS = False

FACING = {'north': (0, 0, -1), 'south': (0, 0, 1), 'east': (1, 0, 0), 'west': (-1, 0, 0), 'up': (0, 1, 0), 'down': (0, -1, 0)}

def open_piston_doors(blocks):
    """El mundo se guardo con las puertas de piston cerradas (piston pegajoso extendido empujando un cristal). Se abren como al
    retraerse en Minecraft: el bloque empujado vuelve al sitio de la cabeza y su casilla queda libre."""
    at = {(b[0], b[1], b[2]): i for i, b in enumerate(blocks)}
    gone = set(); moved = {}
    for b in blocks:
        if b[3] != 'piston_head': continue
        d = FACING.get(b[4].get('facing'))
        if d is None: continue
        head = (b[0], b[1], b[2])
        front = (b[0] + d[0], b[1] + d[1], b[2] + d[2])
        if not OPEN_DOORS:
            # cerrada y tapada: el cristal que la cierra pasa a ser pared
            if front in at:
                j = at[front]
                moved[front] = (front[0], front[1], front[2], 'polished_andesite', {})
                gone.add(j)
            continue
        gone.add(at[head])
        if b[4].get('type') == 'sticky' and front in at:
            j = at[front]
            gone.add(j)
            moved[head] = blocks[j]
    out = [b for i, b in enumerate(blocks) if i not in gone]
    for (x, y, z), b in moved.items():
        out.append((x, y, z, b[3], b[4]))
    print('puertas de piston', 'abiertas:' if OPEN_DOORS else 'tapadas:', len(moved))
    return out

def special(n, pr):
    """Bloques que dependen de sus propiedades. Devuelve el bloque de Galaxy 55, '' para quitarlo o None para usar RULES."""
    if n.endswith('trapdoor'):
        # rejillas de suelo y techo: cerradas arriba ocupan la parte alta (el suelo queda a la misma altura), abajo como placa
        if pr.get('open') == 'true': return ''
        return 'BMotherPanel' if pr.get('half') == 'top' else 'BShipPlate'
    if n.endswith('_door') and not OPEN_DOORS:
        return 'BMotherPanel'
    if n.endswith('_door'):
        # puertas de la nave del original (bloque de 1 de alto que se abre al usarlo, BFToggle): una por cada mitad de la de Minecraft
        f = pr.get('facing')
        return 'BShipDoorY' if f in ('north', 'south') else 'BShipDoor'
    return None

def hull_cells(grid, W, L, H, z0, z1):
    """Columnas (x, y) a menos de 3 casillas del espacio exterior en alguna capa z0..z1: el casco, que nunca se vacia.
    El espacio exterior es el aire conectado con el borde del mapa."""
    out = bytearray(W * L * H)
    def idx(x, y, z): return x + y * W + z * W * L
    q = []
    for z in range(H):
        for y in range(L):
            for x in (0, W - 1):
                if not grid[idx(x, y, z)] and not out[idx(x, y, z)]: out[idx(x, y, z)] = 1; q.append((x, y, z))
        for x in range(W):
            for y in (0, L - 1):
                if not grid[idx(x, y, z)] and not out[idx(x, y, z)]: out[idx(x, y, z)] = 1; q.append((x, y, z))
    while q:
        a, b, c = q.pop()
        for n in ((a+1,b,c),(a-1,b,c),(a,b+1,c),(a,b-1,c),(a,b,c+1),(a,b,c-1)):
            if 0 <= n[0] < W and 0 <= n[1] < L and 0 <= n[2] < H:
                i = idx(*n)
                if not out[i] and not grid[i]: out[i] = 1; q.append(n)
    hull = set()
    for z in range(z0, z1 + 1):
        for y in range(L):
            for x in range(W):
                if out[idx(x, y, z)]:
                    for i in range(-3, 4):
                        for j in range(-3, 4): hull.add((x + i, y + j))
    return hull

def empty_hangar(grid, W, L, H, cells, z, height, mirror=None, hull=None):
    """Quita las naves de adorno y sus pasarelas de atraque de un hangar (lo pidio el usuario, para dejar sitio a las naves
    de los jugadores). La nave ocupa solo parte de las filas del hangar: en cada columna x del interior, lo que esta vacio
    en la mayoria de las filas se vacia en todas. Las columnas de pared (llenas en la mayoria de filas) no se tocan, y el
    suelo, las plataformas y el techo quedan como estan.
    mirror: molde de otro hangar ya vaciado (x -> lista de aire por altura), para el hangar simetrico del otro ala: la nave
    de adorno de algunos ocupa casi todas las filas y la mayoria no basta. Devuelve el molde de este hangar."""
    x0 = min(c[0] for c in cells); x1 = max(c[0] for c in cells)
    y0 = min(c[1] for c in cells); y1 = max(c[1] for c in cells)
    top = z + height                     # primera capa del techo
    def idx(x, y, zz): return x + y * W + zz * W * L
    rows = y1 - y0 + 1
    removed = 0
    mold = {}
    # franja abierta del hangar: columnas libres a media altura en las dos filas de los extremos, con 2 de margen hasta las
    # paredes (las paredes tienen nervios y columnas cada pocas filas que no se deben tocar). Con molde en espejo, la franja
    # es la del hangar simetrico.
    if mirror is None:
        open_x = [x for x in range(x0, x1 + 1)
                  if all(not grid[idx(x, yy, zz)] for yy in (y0, y1) for zz in range(z + 3, z + 10))]
        span = set(range(min(open_x) + 2, max(open_x) - 1)) if open_x else set()
    else:
        span = set(W - 1 - x for x in mirror)
    ceiling = min(top, z + 14)            # las 2 capas de arriba son techo (vigas, luces): no se tocan
    # pared real de cada fila: desde los bordes de la caja hacia dentro, la primera columna libre a media altura
    wall_lo = {}; wall_hi = {}
    for y in range(y0 - 1, y1 + 2):
        lo = x0 - 1
        while lo <= x1 and grid[idx(lo + 1, y, z + 5)]: lo += 1
        hi = x1 + 1
        while hi >= x0 and grid[idx(hi - 1, y, z + 5)]: hi -= 1
        wall_lo[y] = lo; wall_hi[y] = hi
    for x in range(x0, x1 + 1):
        if x not in span: continue
        if mirror is not None and (W - 1 - x) in mirror:
            air = mirror[W - 1 - x]
        else:
            air = [sum(1 for y in range(y0, y1 + 1) if not grid[idx(x, y, zz)]) * 2 >= rows for zz in range(z, ceiling)]
        mold[x] = air
        # columna de interior: libre (en la mayoria de filas) hasta 8 por encima del suelo, sin contar una plataforma baja
        if not all(air[2:9]): continue
        # con molde en espejo se vacia tambien una fila mas por cada lado (las naves de adorno asoman fuera del suelo libre)
        ya, yb = (y0 - 1, y1 + 1) if mirror is not None else (y0, y1)
        for y in range(ya, yb + 1):
            # en cada fila, 2 de margen hasta la pared real de esa fila (en la proa el casco se curva hacia dentro)
            if x < wall_lo[y] + 2 or x > wall_hi[y] - 2: continue
            if hull is not None and (x, y) in hull: continue
            for i, zz in enumerate(range(z, min(top, z + len(air)))):
                if air[i] and grid[idx(x, y, zz)]:
                    grid[idx(x, y, zz)] = 0
                    removed += 1
    if removed: print('hangar x %d-%d y %d-%d: quitados %d bloques de adorno' % (x0, x1, y0, y1, removed))
    return mold

# centros de las plazas de naves (capa de los hangares), marcados por el usuario en un plano
BAY_X = 32
BAY_ROWS = (154, 171, 206, 224, 250)

def find_hangars(grid, W, L, H, z=18, min_cells=500, min_h=14):
    """Los hangares de la Hades (capa 42 del juego = z 18 del mapa): salas grandes de suelo libre con al menos 14 de alto
    (caben las naves del hangar del original, 17x17x14). Devuelve el centro del suelo de cada una, ordenados por y y x."""
    def at(x, y, zz): return grid[x + y * W + zz * W * L]
    def clear(a, b):
        h = 0
        while z + h < H and not at(a, b, z + h): h += 1
        return h
    seen = bytearray(W * L); bays = []; halls = []
    for y0 in range(L):
        for x0 in range(W):
            if seen[x0 + y0 * W] or at(x0, y0, z) or not at(x0, y0, z - 1): continue
            q = [(x0, y0)]; seen[x0 + y0 * W] = 1; cells = []
            while q:
                a, b = q.pop(); cells.append((a, b))
                for c in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
                    if not (0 <= c[0] < W and 0 <= c[1] < L) or seen[c[0] + c[1] * W]: continue
                    if at(c[0], c[1], z) or not at(c[0], c[1], z - 1): continue
                    seen[c[0] + c[1] * W] = 1; q.append(c)
            if len(cells) < min_cells or min(c[0] for c in cells) < W // 2: continue
            hs = sorted(clear(a, b) for a, b in cells)
            if hs[len(hs) // 2] < min_h: continue
            halls.append((cells, hs[-1]))
    # la Hades es simetrica: los hangares del ala izquierda son el espejo de los de la derecha (en la izquierda hay naves
    # de adorno tan grandes que tapan el suelo y no se detectan bien). Primero la derecha; su molde vacia la izquierda.
    halls += [([(W - 1 - a, b) for a, b in cells], h) for cells, h in list(halls)]
    molds = {}
    hull = hull_cells(grid, W, L, H, z, z + 14)
    for cells, height in halls:
        y0 = min(c[1] for c in cells); x0 = min(c[0] for c in cells)
        mirror = molds.get(y0) if x0 < W // 2 else None
        mold = empty_hangar(grid, W, L, H, cells, z, height, mirror, hull)
        if x0 >= W // 2: molds[y0] = mold
    for cells, height in halls:
        # se vacio: recalcular el suelo libre
        cells = [c for c in ((a, b) for a in range(min(c[0] for c in cells), max(c[0] for c in cells) + 1)
                                      for b in range(min(c[1] for c in cells), max(c[1] for c in cells) + 1))
                 if not at(c[0], c[1], z) and at(c[0], c[1], z - 1)]
        if True:
            cx = sum(c[0] for c in cells) // len(cells); cy = sum(c[1] for c in cells) // len(cells)
            # hueco libre de 17x17x14 (nave maxima del hangar) mas cercano al centro: algunos hangares ya tienen naves de adorno
            # hasta 2 plazas por hangar, sin solaparse
            free = set(c for c in cells if clear(*c) >= min_h)
            found = 0
            for _ in range(2):
                best = None
                # empezando por una esquina, asi caben dos en los hangares anchos
                ex = min(c[0] for c in free) if free else cx; ey = min(c[1] for c in free) if free else cy
                for (a, b) in sorted(free, key=lambda c: (c[0] - ex) ** 2 + (c[1] - ey) ** 2):
                    if all((a + i, b + j) in free for i in range(-8, 9) for j in range(-8, 9)):
                        best = (a, b); break
                if best is None: break
                bays.append((best[0], best[1], z)); found += 1
                for i in range(-9, 10):
                    for j in range(-9, 10):
                        free.discard((best[0] + i, best[1] + j))
            if found == 0:
                print('hangar sin hueco libre de 17x17 cerca de', cx, cy)
    # plazas elegidas por el usuario sobre el plano, simetricas: x 32 a la izquierda y su espejo a la derecha; dos por
    # hangar en H3-H6 y una en H7 y H8. Se comprueba que en cada una quepa una nave de 17x17x14.
    chosen = []
    for y in BAY_ROWS:
        for x in (BAY_X, W - 1 - BAY_X):
            ok = all(clear(x + i, y + j) >= min_h for i in range(-8, 9) for j in range(-8, 9))
            if not ok: print('aviso: la plaza', (x, y), 'no esta libre del todo (17x17x14)')
            chosen.append((x, y, z))
    print('hangares: plazas', len(chosen), chosen)
    return chosen

def arrival_hangar(grid, W, L, H, K, home, bays):
    """Añadido del port: el hangar de llegada (de momento la unica zona que se visita). Marca las plazas en el suelo, pone
    el puesto del robot comerciante (mostrador con el ordenador que abre la tienda), una zona de carga, robots hechos de
    bloques (comerciante, de carga y drones) y cierra las salidas del hangar. Devuelve la posicion del ordenador."""
    def idx(x, y, z): return x + y * W + z * W * L
    def put(x, y, z, k): grid[idx(x, y, z)] = K[k] if k else 0
    def get(x, y, z): return grid[idx(x, y, z)]
    fz = home[2]                         # se camina en z 18; el suelo es z 17
    hx, hy = home[0], home[1]
    # caja del hangar: suelo libre conexo alrededor de la llegada
    seen = {(hx, hy)}; q = [(hx, hy)]
    while q:
        a, b = q.pop()
        for c in ((a + 1, b), (a - 1, b), (a, b + 1), (a, b - 1)):
            if c in seen or not (0 <= c[0] < W and 0 <= c[1] < L): continue
            if get(c[0], c[1], fz) or not get(c[0], c[1], fz - 1): continue
            seen.add(c); q.append(c)
    x0 = min(c[0] for c in seen); x1 = max(c[0] for c in seen)
    y0 = min(c[1] for c in seen); y1 = max(c[1] for c in seen)
    # 1) plazas (diseno del usuario, hecho a mano en su plaza): suelo de blindaje claro de 17x17 con borde de franjas de
    # peligro amarillas y negras alternadas, amarillo en las esquinas
    mine = [b for b in bays if x0 <= b[0] <= x1 and y0 <= b[1] <= y1]
    for (bx, by, _) in bays:                            # todas las plazas de los 8 hangares
        for dy in range(-8, 9):
            for dx in range(-8, 9):
                if not get(bx + dx, by + dy, fz - 1): continue
                if abs(dx) == 8 or abs(dy) == 8:
                    put(bx + dx, by + dy, fz - 1, 'BMotherYellow' if (dx + dy) % 2 == 0 else 'BMotherBlack')
                else:
                    put(bx + dx, by + dy, fz - 1, 'BMotherHull')
    # franja libre junto al campo de fuerza, entre las plazas y la pared exterior
    sx0 = max(b[0] for b in mine) + 10 if mine else x0
    sx1 = x1 - 1
    while sx1 > sx0 and any(get(sx1, y, fz) for y in range(y0, y1 + 1)): sx1 -= 1
    cy = (y0 + y1) // 2
    # 2) puesto del comerciante, en el centro de los 8 hangares (lo pidio el usuario): pegado al muro central, entre las dos
    # filas de hangares, con el mostrador mirando a los hangares de la derecha. Estanteria con cajas contra el muro, el
    # robot detras del mostrador, toldo con luz y el ordenador (abre la tienda) en el mostrador.
    mid = W // 2
    # el pasillo entre las dos filas centrales de hangares: el mayor hueco entre plazas
    ys = sorted(set(b[1] for b in bays))
    gap = max(zip(ys, ys[1:]), key=lambda p: p[1] - p[0])
    # al fondo del pasillo de entrada a los hangares, detras de los dos ultimos (el usuario lo marco en un plano): la
    # estanteria contra la pared del fondo, el robot delante y el mostrador mirando hacia los hangares
    cx = mid
    def walk(x, y): return not get(x, y, fz) and (get(x, y, fz - 1) or get(x, y, fz - 2))   # (los surcos cuentan)
    sh = max(b[1] for b in bays) + 9
    while not walk(cx - 4, sh): sh += 1                 # pasar la pared del final de los hangares
    while walk(cx - 4, sh + 1): sh += 1                 # hasta la pared del fondo del pasillo
    # ocupa todo el ancho del tunel (lo pidio el usuario): de pared a pared
    tx0 = cx
    while walk(tx0 - 1, sh): tx0 -= 1
    tx1 = cx
    while walk(tx1 + 1, sh): tx1 += 1
    cy = sh - 7                                         # mostrador, mirando a -y
    def shelf(x, y, z): return 'BShipWire' if z in (fz, fz + 2) else ('BChest' if (x + y + z) % 3 == 0 else 'BWoodPlank')
    for x in range(tx0, tx1 + 1):
        put(x, cy, fz, 'BShipPlate')                    # mostrador de pared a pared
        for y in range(cy, sh + 1): put(x, y, fz + 5, 'BShipTubes')   # toldo
        for z in range(fz, fz + 4): put(x, sh, z, shelf(x, sh, z))    # estanteria del fondo
        if (x - tx0) % 4 == 2: put(x, cy + 3, fz + 5, 'BShipLight')   # luces del toldo
    for y in range(cy + 1, sh):                         # estanterias de las paredes
        for z in range(fz, fz + 3):
            put(tx0, y, z, shelf(tx0, y, z)); put(tx1, y, z, shelf(tx1, y, z))
    for x in (tx0, tx1, cx - 4, cx + 4):                # postes del toldo
        for z in range(fz + 1, fz + 5): put(x, cy, z, 'BIron')
    put(cx, cy, fz, 'BShipComputer')
    for x in (cx - 5, cx + 5): put(x, sh, fz + 4, 'BShedWallLight')
    # el robot comerciante es un personaje del juego (port/game/Robot.hx): aqui solo se guarda donde va y hacia donde mira
    robots = [(cx, cy + 3, fz, 3)]                      # 3 = mira a -y (hacia el mostrador)
    # 3) zona de carga en la esquina del fondo, con un robot de carga
    ly = y1 - 2
    for (x, y, h) in ((sx0, ly, 3), (sx0 + 1, ly, 2), (sx0, ly - 1, 2), (sx0 + 3, ly + 1, 1), (sx0 + 4, ly + 1, 2), (sx0 + 2, ly - 3, 1)):
        for z in range(fz, fz + h): put(x, y, z, 'BWoodPlank' if (x + y + z) % 2 else 'BShipWire')
    # 4) drones (personajes del juego): vuelan en circulo sobre el hangar de llegada y sobre el puesto
    robots.append(((x0 + x1) // 2, (y0 + y1) // 2, fz + 8, 4))
    robots.append((cx, cy - 8, fz + 6, 4))              # 4 = dron
    print('hangar de llegada x %d-%d y %d-%d, ordenador del robot en %s' % (x0, x1, y0, y1, (cx, cy, fz)))
    return robots

def main(world, out):
    K = kinds()
    blocks = open_piston_doors(mcread.blocks(world, True))
    xs = [b[0] for b in blocks]; zs = [b[2] for b in blocks]; ys = [b[1] for b in blocks]
    x0, x1, z0, z1, y0, y1 = min(xs), max(xs), min(zs), max(zs), min(ys), max(ys)
    W, L, H = x1 - x0 + 1, z1 - z0 + 1, y1 - y0 + 1
    grid = array.array('H', [0]) * (W * L * H)
    miss = collections.Counter()
    cache = {}
    rails = []
    for (x, y, z, n, pr) in blocks:
        sp = special(n, pr)
        if sp is not None:
            if sp:
                grid[(x - x0) + (z1 - z) * W + (y - y0) * W * L] = K[sp]
            continue
        if n not in cache:
            g = 'skip'
            for frag, tgt in RULES:
                if frag in n:
                    g = tgt
                    break
            cache[n] = g
        g = cache[n]
        if g == 'skip':
            miss[n] += 1
            continue
        if g is None: continue
        gx, gy, gz = x - x0, (z1 - z), y - y0
        if g == 'RAIL':
            rails.append(gx + gy * W + gz * W * L)
            continue
        grid[gx + gy * W + gz * W * L] = K[g]
    # los railes del suelo separan los hangares: se buscan los hangares sin ellos y despues se ponen
    bays = find_hangars(grid, W, L, H)
    # aparicion: donde estaba el jugador
    sx, sy, sz = W // 2, L // 2, H
    pd = os.path.join(world, 'playerdata')
    for fn in os.listdir(pd):
        if fn.endswith('.dat'):
            import gzip
            p = mcread.nbt(gzip.decompress(open(os.path.join(pd, fn), 'rb').read()))['Pos']
            sx, sy, sz = int(p[0]) - x0, z1 - int(p[2]), int(p[1]) - y0
            break
    sx, sy, sz = [max(0, min(v, m - 1)) for v, m in ((sx, W), (sy, L), (sz, H))]
    robots = []
    if bays:
        # se aparece en una plaza de un hangar; el puesto del robot comerciante esta en el centro de los 8 hangares
        home = max((b for b in bays if b[1] > L // 2), key=lambda b: b[0], default=bays[0])
        sx, sy, sz = home
        robots = arrival_hangar(grid, W, L, H, K, home, bays)
        print('llegada', home, 'robots', robots)
    for i in rails:
        if not grid[i]: grid[i] = K['BShipTubes']
    write_g55p(out, W, L, H, (sx, sy, sz), bays, robots, grid, sorted(K, key=K.get))
    print('medidas', W, L, H, 'aparicion', sx, sy, sz, 'bloques', sum(1 for v in grid if v))
    print('sin traducir:', miss.most_common(30))

if __name__ == '__main__':
    if sys.argv[1] == '--convert': convert(sys.argv[2], sys.argv[3])
    else: main(sys.argv[1], sys.argv[2])
