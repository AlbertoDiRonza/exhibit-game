extends Control
class_name ArTouchJoystick
## Joystick touch per muoversi in AR (dove non c'è tastiera). Si tocca e si
## trascina: la distanza dal centro diventa "output", un Vector2 -1..1 che
## player.gd legge per muovere il personaggio. Disegnato a mano con _draw(),
## niente texture esterne.

@export var knob_radius: float = 40.0
@export var base_radius: float = 90.0
@export var dead_zone: float = 0.15

## Direzione corrente, letta da player.gd (-1..1 per asse; y: avanti = -1).
var output: Vector2 = Vector2.ZERO

var _touch_index: int = -1
var _touch_origin: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _draw() -> void:
	# Il cerchio base resta fisso al centro, anche se il tocco iniziale non
	# ci cade esattamente sopra (più comodo da usare col pollice).
	var center := size / 2.0
	draw_circle(center, base_radius, Color(1, 1, 1, 0.18))
	draw_arc(center, base_radius, 0, TAU, 48, Color(1, 1, 1, 0.55), 3.0, true)
	draw_circle(center + _knob_offset, knob_radius, Color(1, 1, 1, 0.5))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch_index == -1:
			_touch_index = event.index
			_touch_origin = size / 2.0
			_update_knob(event.position)
		elif not event.pressed and event.index == _touch_index:
			_touch_index = -1
			_reset()
	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_update_knob(event.position)
	# Fallback col mouse, comodo per testare da editor/desktop.
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_touch_index = 0
			_touch_origin = size / 2.0
			_update_knob(event.position)
		elif _touch_index == 0:
			_touch_index = -1
			_reset()
	elif event is InputEventMouseMotion and _touch_index == 0:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_update_knob(event.position)


func _update_knob(local_pos: Vector2) -> void:
	var delta := local_pos - _touch_origin
	if delta.length() > base_radius:
		delta = delta.normalized() * base_radius
	_knob_offset = delta

	var raw := delta / base_radius
	output = raw if raw.length() > dead_zone else Vector2.ZERO
	queue_redraw()


func _reset() -> void:
	_knob_offset = Vector2.ZERO
	output = Vector2.ZERO
	queue_redraw()
