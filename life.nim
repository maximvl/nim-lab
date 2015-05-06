import math, threadpool
import sdl2, sdl2/gfx

discard sdl2.init(INIT_EVERYTHING)

const 
  size_x = 100
  size_y = 100

type 
  Cell = enum EmptyCell, AliveCell # , SkipCell
  Field = array[0..size_y, array[0..size_x, Cell]]

let
  empty_color = uint32(SDL_DEFINE_PIXELFOURCC(255, 255, 255, 0))
  alive_color = uint32(SDL_DEFINE_PIXELFOURCC(0, 255, 0, 0))
  cell_size = 7                 # pixels
  windowWidth = (cell_size * size_y).cint
  windowHeight = (cell_size * size_x).cint
  max_x = windowWidth
  max_y = windowHeight

var
  field: Field
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

  # texture: TexturePtr

  surface = createRGBSurface(0,
                             window_width, window_height,
                             32,
                             0x00FF0000,
                             0x0000FF00,
                             0x000000FF,
                             0xFF000000)

proc draw_field() =
  texture.lockTexture(nil, addr(surface.pixels), addr(surface.pitch))
  for row in 0..size_y:
    for col in 0..size_x:
      var color: uint32
      case field[row][col]
      # of SkipCell:
      #   continue
      of EmptyCell:
        color = empty_color
      of AliveCell:
        color = alive_color
      let
        row2 = row*cell_size
        col2 = col*cell_size
      var
        rect = rect(cint(row2), cint(col2), 
                    cint(row2 + cell_size), 
                    cint(col2 + cell_size))
      surface.fillRect(addr[Rect](rect), color)
  texture.updateTexture(nil, surface.pixels, surface.pitch)
  texture.unlockTexture()

proc random_fill() =
  randomize()
  for row in 0..size_y:
    for col in 0..size_x:
      let alive = bool(random(2))
      if alive:
        field[row][col] = AliveCell
      else:
        field[row][col] = EmptyCell

proc reset_field() =
  for row in 0..size_y:
    for col in 0..size_x:
      field[row][col] = EmptyCell

proc bound(v: int, max_v: cint): int =
  if v < 0:
    return max_v + v
  elif v >= max_v:
    return v - max_v
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
    if field[x1][y1] == AliveCell:
      result += 1

proc update_cell(field: var Field, row: int, col: int) =
  let alives = alives_around(row, col)
  case alives
  of 3:
    if field[row][col] == EmptyCell:
      field[row][col] = AliveCell
    # else:
    #   field[row][col] = SkipCell
  of 2:
    # field[row][col] = SkipCell
    discard
  else:
    if field[row][col] == AliveCell:
      field[row][col] = EmptyCell
    # else:
    #   field[row][col] = SkipCell

proc update_field() =
  var field2 = field
  parallel:
    for row in 0..size_y:
      for col in 0..size_x:
        spawn update_cell(field2, row, col)
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
# fpsman.setFramerate(1.cint)


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
      case field[x][y]
      of EmptyCell:
        field[x][y] = AliveCell
      of AliveCell:
        field[x][y] = EmptyCell
      else:
        discard

  # let dt = fpsman.getFramerate() / 1000
  # echo dt

  # render.setDrawColor 0, 0, 0, 255
  # render.clear

  if not pause_game:
    update_field()

  draw_field()
  # texture = render.createTexture(surface)
  render.copy(texture, nil, nil)
  render.present
  # fpsman.delay

destroy render
destroy window
