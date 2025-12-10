extends Control

@onready var slots_grid = $InventoryPanel/SlotsGrid
@onready var selected_icon = $SelectedItemPanel/SelectedItemIcon
@onready var selected_name = $SelectedItemPanel/SelectedItemName
@onready var selected_description = $SelectedItemPanel/SelectedItemDescription
@onready var context_menu = $ItemContextMenu

var is_open = false
var selected_index = -1

var dragging_item: Texture2D = null
var dragging_name: String = ""
var dragging_description: String = ""
var dragging_stack: int = 1
var dragging_icon: TextureRect = null
var using_mouse_drag: bool = false

var _last_hover_index: int = -1

func is_inventory_open() -> bool:
	return is_open

func _ready():
	# Começa fechado
	hide()
	_update_selection_visual()

	# Ícone flutuante
	dragging_icon = TextureRect.new()
	dragging_icon.modulate = Color(1, 1, 1, 0.8)
	dragging_icon.visible = false
	dragging_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dragging_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH
	add_child(dragging_icon)
	dragging_icon.custom_minimum_size = Vector2(74, 74)

func _process(_delta):
	# Se o menu de contexto estiver aberto, o inventário fica "congelado" visuamente,
	# mas ainda atualizamos pos do ícone flutuante para ficar consistente.
	if not is_open:
		return

	# Atualizações visuais e hover (sem ler teclas aqui)
	_handle_mouse_hover()
	_update_selection_visual()

	# Atualiza posição do ícone flutuante (se houver)
	if dragging_item:
		if using_mouse_drag:
			dragging_icon.global_position = get_viewport().get_mouse_position() + Vector2(-15, -40)
		else:
			# Modo teclado: segue o slot selecionado (garante index válido)
			if selected_index >= 0 and selected_index < slots_grid.get_child_count():
				var slot = slots_grid.get_child(selected_index)
				var parent_global = dragging_icon.get_parent().get_global_position()
				var base_pos = slot.get_global_position() - parent_global
				dragging_icon.global_position = base_pos + Vector2(25, -20)

# ---------- Entrada (teclado/mouse) centralizada aqui ----------
func _input(event):
	# Sempre permitir toggle do inventário mesmo quando fechado
	if event is InputEventKey and event.pressed and not event.echo:
		if Input.is_action_pressed("inventory_toggle"):
			is_open = not is_open
			if is_open:
				show()
				# inicializa seleção se necessário
				if selected_index < 0 and slots_grid.get_child_count() > 0:
					selected_index = 0
					_update_selected_item_info()
			else:
				hide()
			# consumiu a tecla de toggle
			return

	# Se inventário fechado, ignore outras interações
	if not is_open:
		return

	# Se menu de contexto visível: somente navegação do menu (bloqueia inven)
	if context_menu.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			if Input.is_action_pressed("inv_up"):
				context_menu.navigate_up()
			elif Input.is_action_pressed("inv_down"):
				context_menu.navigate_down()
			elif Input.is_action_pressed("open_context_menu"): # por exemplo ENTER
				context_menu.activate_selected()
				context_menu.hide_menu()
			elif Input.is_action_pressed("ui_cancel"):
				context_menu.hide_menu()
		# se for mouse, deixar o menu tratar seus próprios clicks (não precisa aqui)
		return

	# --- Teclado: navegação e ações (tratadas apenas aqui para evitar duplicação) ---
	if event is InputEventKey and event.pressed and not event.echo:
		# navegação por setas / WASD mapeadas para ações inv_*
		if Input.is_action_pressed("inv_left"):
			selected_index = max(selected_index - 1, 0)
			_update_selected_item_info()
			return
		elif Input.is_action_pressed("inv_right"):
			selected_index = min(selected_index + 1, slots_grid.get_child_count() - 1)
			_update_selected_item_info()
			return
		elif Input.is_action_pressed("inv_up"):
			selected_index = max(selected_index - slots_grid.columns, 0)
			_update_selected_item_info()
			return
		elif Input.is_action_pressed("inv_down"):
			selected_index = min(selected_index + slots_grid.columns, slots_grid.get_child_count() - 1)
			_update_selected_item_info()
			return

		# Drag (espaço) -> começa / solta item
		if Input.is_action_pressed("drag_item") and selected_index >= 0:
			toggle_drag()
			using_mouse_drag = false
			return

		# Abrir menu de contexto com tecla (ex: Enter) — só quando não estiver arrastando
		if Input.is_action_pressed("open_context_menu") and not dragging_item and selected_index >= 0:
			var slot = slots_grid.get_child(selected_index)
			if slot.item_texture:
				var pos = slot.get_global_position() + Vector2(0, slot.size.y)
				context_menu.show_at_position(pos)
			return

	# --- Mouse inputs ---
	if event is InputEventMouseButton and event.pressed:
		# Clique esquerdo: pick up / drop
		if event.button_index == MOUSE_BUTTON_LEFT:
			for i in range(slots_grid.get_child_count()):
				var slot = slots_grid.get_child(i)
				# event.position é coordenada da viewport (global)
				if slot.get_global_rect().has_point(event.position):
					selected_index = i
					_update_selection_visual()
					toggle_drag()
					using_mouse_drag = dragging_item != null
					return

		# Clique direito: abrir menu de contexto (na seleção atual)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# atualize seleção pelo mouse se clicou em um slot
			for i in range(slots_grid.get_child_count()):
				var slot = slots_grid.get_child(i)
				if slot.get_global_rect().has_point(event.position):
					selected_index = i
					_update_selection_visual()
					# só abre se tiver item
					if slot.item_texture:
						var pos = slot.get_global_position() + Vector2(0, slot.size.y)
						context_menu.show_at_position(pos)
					return

# ---------- Resto das funções (sem mudanças lógicas, só mais seguras) ----------
func _handle_mouse_hover():
	if not is_open:
		return

	var mouse_pos = get_viewport().get_mouse_position()
	var found_index := -1
	for i in range(slots_grid.get_child_count()):
		var slot = slots_grid.get_child(i)
		if not slot.visible:
			continue
		if slot.get_global_rect().has_point(mouse_pos):
			found_index = i
			break

	if found_index != -1:
		if _last_hover_index != found_index:
			_last_hover_index = found_index
			if not dragging_item:
				selected_index = found_index
				_update_selection_visual()
				_update_selected_item_info()
			else:
				selected_index = found_index
				_update_selection_visual()
	else:
		if _last_hover_index != -1:
			_last_hover_index = -1
			if not dragging_item:
				selected_index = -1
				_update_selection_visual()
				_update_selected_item_info()

func add_item(item: ItemData):
	for i in range(slots_grid.get_child_count()):
		var slot = slots_grid.get_child(i)
		if slot.item_texture == null:
			slot.item_texture = item.item_texture
			slot.item_description = item.item_description
			slot.item_name = item.item_name
			slot.update_slot()
			return

func toggle_drag():
	# proteção: índice válido
	if selected_index < 0 or selected_index >= slots_grid.get_child_count():
		return

	var slot = slots_grid.get_child(selected_index)

	# se já está arrastando, tenta colocar no slot
	if dragging_item:
		if slot.item_texture == null:
			# slot vazio: coloca o item
			slot.item_texture = dragging_item
			slot.item_name = dragging_name
			slot.item_description = dragging_description
			slot.stack_count = dragging_stack
			slot.update_slot()
			_stop_drag()
		else:
			# slot cheio: troca de lugar
			var temp_texture = slot.item_texture
			var temp_name = slot.item_name
			var temp_desc = slot.item_description
			var temp_stack = slot.stack_count

			slot.item_texture = dragging_item
			slot.item_name = dragging_name
			slot.item_description = dragging_description
			slot.stack_count = dragging_stack
			slot.update_slot()

			dragging_item = temp_texture
			dragging_name = temp_name
			dragging_description = temp_desc
			dragging_stack = temp_stack
			dragging_icon.texture = dragging_item
			dragging_icon.visible = true
	else:
		# começa o drag (se houver item no slot)
		if slot.item_texture:
			dragging_item = slot.item_texture
			dragging_name = slot.item_name
			dragging_description = slot.item_description
			dragging_stack = slot.stack_count
			dragging_icon.texture = dragging_item
			dragging_icon.visible = true

			slot.item_texture = null
			slot.item_name = ""
			slot.item_description = ""
			slot.stack_count = 0
			slot.update_slot()

func _stop_drag():
	dragging_item = null
	dragging_name = ""
	dragging_description = ""
	dragging_stack = 1
	dragging_icon.visible = false

func _update_selection_visual():
	for i in range(slots_grid.get_child_count()):
		var slot = slots_grid.get_child(i)
		if i == selected_index:
			slot.modulate = Color(1, 1, 1)
			slot.self_modulate = Color(1.2, 1.2, 1.2)
		else:
			slot.self_modulate = Color(0.8, 0.8, 0.8)

func _update_selected_item_info():
	if selected_index < 0 or selected_index >= slots_grid.get_child_count():
		selected_icon.texture = null
		selected_name.text = "N/A"
		selected_description.text = "N/A"
		return

	var selected_slot = slots_grid.get_child(selected_index)
	selected_icon.texture = selected_slot.item_texture if selected_slot.item_texture else null
	selected_name.text = selected_slot.item_name if selected_slot.item_name != "" else "Sem nome"
	selected_description.text = selected_slot.item_description if selected_slot.item_description != "" else "Sem descrição."
