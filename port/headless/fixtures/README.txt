Partidas .json de antes para SaveTest (migracion a .g55):
  legacy_mixta.json   bloques 300, 301 y 302 en cada sitio que guarda bloques (inventario, terreno con agua y mar, nave,
                      planeta visitado, cantina, precios del robot, tutorial) y un kube del editor (editorKubes): con la tabla
                      upstream son BKubeMystery y los dos siguientes; con la del fork, los dos de Grey Haven y BKubeMystery
  legacy_minima.json  solo version, seed y biome: lo que falta toma su valor de siempre (inventario inicial, sin universo)
  legacy_mal.json     un inventario mal formado: error con el nombre del campo (antes se ponia el kit creativo sin decir nada)
  legacy_desconocidos.json  creativa con los bloques 400 y 401 en el inventario, que ninguna de las dos lineas tiene: pasan a
                      kubes de remplazo ("#400", "#401") que se guardan tal cual (port/dev/bloques_desconocidos.txt); con
                      genVersion 1 para que no sea una partida antigua (esa la prueba port/dev/partida_antigua.txt)
