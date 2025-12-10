extends Control

@onready var usar_button = $UseButton
@onready var largar_button = $DropButton
@onready var sair_button = $LeaveButton

var buttons: Array = []        # <-- inicializa vazia
var selected_index = 0


func _ready():
	buttons = [usar_button, largar_button, sair_button]   # <-- agora é SEGURO
	_update_selection()
	hide()


func show_at_position(pos: Vector2):
	print("Menu aberto em:", pos)
	global_position = pos
	selected_index = 0
	_update_selection()
	show()


func hide_menu():
	hide()


func _update_selection():
	for i in range(buttons.size()):
		if buttons[i] == null:
			continue
		if i == selected_index:
			buttons[i].add_theme_color_override("font_color", Color.YELLOW)
		else:
			buttons[i].add_theme_color_override("font_color", Color.WHITE)


func navigate_up():
	selected_index = (selected_index - 1 + buttons.size()) % buttons.size()
	_update_selection()


func navigate_down():
	selected_index = (selected_index + 1) % buttons.size()
	_update_selection()


func activate_selected():
	if buttons.size() == 0:
		return
	if selected_index < 0 or selected_index >= buttons.size():
		return
	if buttons[selected_index] == null:
		return
		buttons[selected_index].emit_signal("pressed")


func _on_leave_button_pressed():
	hide_menu()       # Fecha só o menu suspenso
	emit_signal("cancelled")  # inventário pode ouvir isso se quiser
