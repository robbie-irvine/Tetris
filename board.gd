extends TileMap

const PIECES = {
	"l1": {
		"shape": [Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(-1,1)],
		"rotations": 4,
		"multiplier": Vector2i(-1,1),
		"sprite": Vector2i(1,0)
	},
	"l2": {
		"shape": [Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(1,1)],
		"rotations": 4,
		"multiplier": Vector2i(-1,1),
		"sprite": Vector2i(2,0)
	},
	"t": {
		"shape": [Vector2i(0,0),Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1)],
		"rotations": 4,
		"multiplier": Vector2i(-1,1),
		"sprite": Vector2i(5,0)
	},
	"line": {
		"shape": [Vector2i(-1,0),Vector2i(-0,0),Vector2i(1,0),Vector2i(-2,0)],
		"rotations": 2,
		"multiplier": Vector2i(-1,1),
		"sprite": Vector2i(6,0)
	},
	"square": {
		"shape": [Vector2i(0,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(-1,1)],
		"rotations": 1,
		"multiplier": Vector2i(-1,1),
		"sprite": Vector2i(0,0)
	},
	"s1": {
		"shape": [Vector2i(-1,1),Vector2i(0,1),Vector2i(0,0),Vector2i(1,0)],
		"rotations": 2,
		"multiplier": Vector2i(1,-1),
		"sprite": Vector2i(3,0)
	},
	"s2": {
		"shape": [Vector2i(-1,0),Vector2i(0,0),Vector2i(0,1),Vector2i(1,1)],
		"rotations": 2,
		"multiplier": Vector2i(1,-1),
		"sprite": Vector2i(4,0)
	}
}

const BORDER_LAYER = 0
const ACTIVE_LAYER = 1
const PLACED_LAYER = 2
const NEXT_PIECE_LAYER = 3

var offset = Vector2i(0,0)
var active_piece
var next_piece
var active_shape = []
var rotations = 0
var to_be_placed = false
var random_bag = []

func rotate_shape():
	var new_shape = []
	var new_rotations = rotations
	
	# reset rotation, used for 2 rotation pieces
	if new_rotations+1 >= active_piece.rotations:
		new_shape = active_piece.shape
		new_rotations = 0
		draw_shape()
	else: # rotate as normal
		for i in active_shape:
			new_shape += [Vector2i(i.y,i.x) * active_piece.multiplier]
		new_rotations += 1
	
	# check that block can be rotated before committing to it
	var do_rotate = true
	
	for i in new_shape:
		if !is_cell_empty(BORDER_LAYER, i+offset) || !is_cell_empty(PLACED_LAYER, i+offset):
			do_rotate = false
			break
	
	if do_rotate:
		rotations = new_rotations
		active_shape = new_shape
		draw_shape()
		$Sounds/Rotate.play()

func is_cell_empty(layer, vector2location):
	var rtn = get_cell_atlas_coords(layer, vector2location) == Vector2i(-1,-1)
	return rtn

func move_cell_down(cell_location: Vector2i):
	var new_loc = cell_location
	new_loc.y += 1
	var cell_sprite = get_cell_atlas_coords(PLACED_LAYER, cell_location)
	set_cell(PLACED_LAYER, new_loc, 0, cell_sprite)
	erase_cell(PLACED_LAYER, cell_location)
	pass

func clear_any_rows():
	var lines_cleared = []
	for y in 20: # for every row
		var block_range = range(-5,5)
		var clear_this_row = true
		
		# would love to make this an any function but gdscript says no
		for x in block_range:
			if is_cell_empty(PLACED_LAYER, Vector2i(x,y)):
				clear_this_row = false
				break
		
		if clear_this_row:
			lines_cleared.append(y)
			block_range.map(func(x): erase_cell(PLACED_LAYER, Vector2i(x,y)))
			# get all cells above the current y level
			var all_cells = get_used_cells(PLACED_LAYER)
			for y2 in range(y-1, -1, -1):
				all_cells.map(func(v): if v.y == y2: move_cell_down(v))
	
	var lc_size = lines_cleared.size()
	if lc_size > 0 && lc_size < 4:
		$Sounds/ClearLine.play()
	elif lc_size > 0:
		$Sounds/Tetris.play()

func place_block():
	active_shape.filter(func(i): set_cell(PLACED_LAYER, i+offset, 0, active_piece.sprite))
	clear_layer(ACTIVE_LAYER)
	$Sounds/Place.play()
	clear_any_rows()
	new_block()

func draw_next_shape():
	clear_layer(NEXT_PIECE_LAYER)
	var next_offset = Vector2i(9,2)
		
	for i in next_piece.shape:
		set_cell(NEXT_PIECE_LAYER, i + next_offset, 0, next_piece.sprite)

func draw_shape():
	if to_be_placed:
		place_block()
	else:
		clear_layer(ACTIVE_LAYER)
		
		for i in active_shape:
			set_cell(ACTIVE_LAYER, i + offset, 0, active_piece.sprite)

func update_offset(x_val, y_val):
	var new_offset = Vector2i(offset.x + x_val, offset.y + y_val)
	
	for i in active_shape:
		if !is_cell_empty(BORDER_LAYER, i+new_offset) || !is_cell_empty(PLACED_LAYER, i+new_offset):
			if offset.y < new_offset.y: to_be_placed = true
			draw_shape()
			return
	
	# if no blocks underneath
	offset.x += x_val
	offset.y += y_val
	draw_shape()

func lower_piece():
	update_offset(0,1)

func new_block():
	to_be_placed = false
	active_piece = next_piece
	new_next_piece()
	active_shape = active_piece.shape
	offset = Vector2i(0,0)
	rotations = 0
	draw_shape()

func new_next_piece():
	# if bag is empty, initialise it with the index of every block (so range i think)
	if random_bag.is_empty():
		random_bag = range(PIECES.size())
	
	# pick a random element of the array
	var bag_size = random_bag.size()
	var bag_key = randi() % bag_size
	var bag_value = random_bag[bag_key]
	
	# find the dictionary value associated with this random number,
	# then remove it from bag
	next_piece = PIECES[PIECES.keys()[bag_value]]
	random_bag.remove_at(bag_key)
	
	draw_next_shape()

# Called when the node enters the scene tree for the first time.
func _ready():
	new_next_piece()
	new_block()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if (Input.is_action_just_pressed("ui_select")):
		rotate_shape()
	
	if Input.is_action_just_pressed("ui_left"):
		update_offset(-1, 0)
	
	if Input.is_action_just_pressed("ui_right"):
		update_offset(1, 0)
	
	if Input.is_action_just_pressed("ui_down"):
		lower_piece()
		$Timer.start(0.05)
	if Input.is_action_just_released("ui_down"):
		$Timer.start(1)


func _on_timer_timeout():
	lower_piece()
