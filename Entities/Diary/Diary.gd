extends Control
class_name Diary

@export var pages: Array[PackedScene] = []
@onready var left_page: Control = %LeftPage
@onready var right_page: Control = %RightPage

var current_left_page := 1 :
	set = set_current_left_page

signal current_page_changed(page: int)

func _ready() -> void:
	add_current_data_on_left_page()
	add_current_data_on_right_page()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		if current_left_page > 1:
			current_left_page -= 2
	
	if event.is_action_pressed("ui_right"):
		if current_left_page < pages.size() - 1:
			current_left_page += 2

func add_current_data_on_left_page() -> void:
	var left_page_content = pages[current_left_page - 1].instantiate()
	left_page_content.name = "page_%d" % current_left_page
	
	left_page.add_child(left_page_content)

func add_current_data_on_right_page() -> void:
	var right_page_content = pages[current_left_page].instantiate()
	right_page_content.name = "page_%d" % (current_left_page + 1)  
	
	right_page.add_child(right_page_content)


func set_current_left_page(value: int) :
	current_left_page = value
	
	current_page_changed.emit(value)
	
	for page in left_page.get_children():
		page.visible = false
	
	if not left_page.find_child("page_%d" % current_left_page):
		add_current_data_on_left_page()
	
	for page in right_page.get_children():
		page.visible = false
	
	if not right_page.find_child("page_%d" % (current_left_page + 1)):
		add_current_data_on_right_page()
	
	#for page: Node2D in left_page.get_children():
		#page.visible = false
