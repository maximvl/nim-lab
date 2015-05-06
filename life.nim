import math, threadpool
import sdl2, sdl2/gfx

discard sdl2.init(INIT_EVERYTHING)

const 
  size_x = 300
  size_y = 300

type 
  CellType = enum EmptyCell, AliveCell
  Cell = tuple[kind: CellType, skip: bool]
  Field = array[0..size_y, array[0..size_x, Cell]]

let
  empty_color = color(255, 255, 255, 0)
  alive_color = color(0, 255, 0, 0)
  cell_size = 2                 # pixels

var
  field: Field
  window: WindowPtr
  render: RendererPtr

let
  windowWidth = (cell_size * len(field)).cint
  windowHeight = (cell_size * len(field[0])).cint
  max_x = windowWidth
  max_y = windowHeight

window = createWindow("Game Of Life", 100, 100,
                      windowWidth, windowHeight,
                      SDL_WINDOW_SHOWN)

render = createRenderer(window, -1, 
                        Renderer_Accelerated or 
                        Renderer_PresentVsync or
                        Renderer_TargetTexture)

proc draw_field() =
  for row in 0..size_y:
    for col in 0..size_x:
      if field[row][col].skip:
        continue

      let color = case field[row][col].kind
      of EmptyCell:
        empty_color
      of AliveCell:
        alive_color
      render.setDrawColor(color.r, color.g, color.b, color.a)
      let 
        row2 = row*cell_size
        col2 = col*cell_size
      var rect = rect(cint(row2), cint(col2), 
                      cell_size.cint, cell_size.cint)
      render.fillRect(rect)

proc random_fill() =
  randomize()
  for row in 0..size_y:
    for col in 0..size_x:
      let alive = bool(random(2))
      if alive:
        field[row][col].kind = AliveCell
      else:
        field[row][col].kind = EmptyCell
      field[row][col].skip = false

proc reset_field() =
  for row in 0..size_y:
    for col in 0..size_x:
      field[row][col].kind = EmptyCell
      field[row][col].skip = false

proc bound(v: int, max_v: cint): int =
  let max2 = max_v + 1
  if v < 0:
    return max2 + v
  elif v >= max2:
    return v - max2
  return v

proc alives_around(x: int, y: int): int =
  const coords = [(-1, -1), (-1, 0), (-1, 1),
                  (0,  -1),          (0, 1),
                  (1,  -1), (1,  0), (1, 1)]
  result = 0
  for c in coords:
    let
      x1 = bound(x + c[0], size_x)
      y1 = bound(y + c[1], size_y)
    if field[x1][y1].kind == AliveCell:
      result += 1

proc update_cell(c: var Cell, x: int, y: int) =
  let alives = alives_around(x, y)
  case alives
  of 3:
    if c.kind == EmptyCell:
      c.kind = AliveCell
      c.skip = false
    else:
      c.skip = true
  of 2:
    c.skip = true
  else:
    if c.kind == AliveCell:
      c.kind = EmptyCell
      c.skip = false
    else:
      c.skip = true

proc update_row(field: var Field, row: int) =
  for col in 0..size_x:
    update_cell(field[row][col], row, col)

proc update_field() =
  var field2 = field
  parallel:
    for row in 0..size_y:
      spawn update_row(field2, row)
  field = field2

proc draw_net(step: int) =
  render.setDrawColor(0x1d, 0x1f, 0x21, 0)
  var i = 0
  while i < max_x:
    render.drawLine(i.cint, 0.cint, i.cint, max_y)
    i += step
  i = 0
  while i < max_y:
    render.drawLine(0.cint, i.cint, max_x, i.cint)
    i += step

var
  evt = sdl2.defaultEvent
  run_game = true
  pause_game = false
  fpsman: FpsManager

fpsman.init
# fpsman.setFramerate(cint(0.9))

render.setDrawColor 255, 255, 255, 255
render.clear

while run_game:
  while pollEvent(evt):
    if evt.kind == QuitEvent:
      run_game = false
      break
    if evt.kind == KeyDown:
      let keyboardEvent = cast[KeyboardEventPtr](addr(evt))
      case keyboardEvent.keysym.scancode
      of SDL_SCANCODE_C:
        reset_field()
      of SDL_SCANCODE_R:
        random_fill()
      of SDL_SCANCODE_Q, SDL_SCANCODE_ESCAPE:
        run_game = false
        break
      of SDL_SCANCODE_SPACE:
        pause_game = not pause_game
      else:
        discard
    if evt.kind == MouseButtonDown:
      let
        mouseEvent = cast[MouseButtonEventPtr](addr(evt))
        x = round(floor(mouseEvent.x / cell_size))
        y = round(floor(mouseEvent.y / cell_size))
      case field[x][y].kind
      of EmptyCell:
        field[x][y].kind = AliveCell
      of AliveCell:
        field[x][y].kind = EmptyCell
      field[x][y].skip = false

  # let dt = fpsman.getFramerate() / 1000
  # echo dt

  if not pause_game:
    update_field()

  draw_field()

  render.present
  fpsman.delay

destroy render
destroy window
