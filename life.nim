import math, threadpool
import sdl2, sdl2/gfx

discard sdl2.init(INIT_EVERYTHING)

const 
  size_x = 300
  size_y = 300

type 
  CellType = enum EmptyCell, AliveCell
  Cell = tuple[kind: CellType, skip: bool]
  FieldObj = array[0..size_y, array[0..size_x, Cell]]
  Field = ref FieldObj

let
  empty_color = uint32(SDL_DEFINE_PIXELFOURCC(255, 255, 255, 0))
  alive_color = uint32(SDL_DEFINE_PIXELFOURCC(0, 255, 0, 0))
  cell_size = 2                 # pixels
  windowWidth = (cell_size * size_y).cint
  windowHeight = (cell_size * size_x).cint
  max_x = windowWidth
  max_y = windowHeight

var
  field: Field
  field2: Field
  window = createWindow("Game Of Life", 100, 100,
                        windowWidth, windowHeight,
                        SDL_WINDOW_SHOWN)
  render = createRenderer(window, -1, 
                          Renderer_Accelerated or 
                          Renderer_PresentVsync or
                          Renderer_TargetTexture)

  texture = render.createTexture(SDL_PIXELFORMAT_ARGB8888, 
                                 SDL_TEXTUREACCESS_STREAMING,
                                 window_width,
                                 window_height)

  surface = createRGBSurface(0,
                             window_width, window_height,
                             32,
                             0x00FF0000,
                             0x0000FF00,
                             0x000000FF,
                             0xFF000000)

new(field)
new(field2)

proc draw_field() =
  texture.lockTexture(nil, addr(surface.pixels), addr(surface.pitch))
  for row in 0..size_y:
    for col in 0..size_x:
      if field[row][col].skip:
        continue
      let 
        row2 = row*cell_size
        col2 = col*cell_size
        color = case field[row][col].kind
        of EmptyCell:
          empty_color
        of AliveCell:
          alive_color
      var rect = rect(cint(row2), cint(col2), 
                      cell_size.cint, cell_size.cint)
      surface.fillRect(addr[Rect](rect), color)
  texture.unlockTexture()

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

proc reset_field(field: Field) =
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

proc alives_around(field: Field, y: int, x: int): int =
  const coords = [(-1, -1), (-1, 0), (-1, 1),
                  (0,  -1),          (0, 1),
                  (1,  -1), (1,  0), (1, 1)]
  result = 0
  for c in coords:
    let
      x1 = bound(x + c[0], size_x)
      y1 = bound(y + c[1], size_y)
    if field[y1][x1].kind == AliveCell:
      result += 1

proc update_cell(c: var Cell, x: int, y: int, alives: int) =
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

proc print_field(field: Field) =
  for row in 0..size_y:
    for col in 0..size_x:
      case field[row][col].kind
      of AliveCell:
        write(stdout, "#")
      of EmptyCell:
        write(stdout, ".")
    echo()
  echo()

proc update_row(field: Field, field2: Field, row: int) =
  for col in 0..size_x:
    let alives = alives_around(field, row, col)
    field2[row][col].kind = field[row][col].kind
    update_cell(field2[row][col], row, col, alives)

proc update_field() =
  for row in 0..size_y:
    update_row(field, field2, row)
  swap(field, field2)

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
  pause_game = true
  step = false
  fpsman: FpsManager

fpsman.init
# fpsman.setFramerate(cint(0.9))

render.setDrawColor 255, 255, 255, 0
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
        reset_field(field)
        reset_field(field2)
      of SDL_SCANCODE_R:
        random_fill()
      of SDL_SCANCODE_Q, SDL_SCANCODE_ESCAPE:
        run_game = false
        break
      of SDL_SCANCODE_SPACE:
        pause_game = not pause_game
      of SDL_SCANCODE_S:
        step = not step
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
    if step:
      pause_game = true

  draw_field()

  render.copy(texture, nil, nil)
  render.present
  fpsman.delay

destroy render
destroy window
