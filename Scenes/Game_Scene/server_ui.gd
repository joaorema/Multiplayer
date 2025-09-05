# UI.gd - Attach to your UI Control node
extends Control

@onready var multiplayer_manager = get_node("%Server")
@onready var ip_input: LineEdit = %Ip_input  # Add this LineEdit to your UI
@onready var host_button: Button = %Host
@onready var join_button: Button = %Join
@onready var server_label: Label = %Server_ip



func _on_host_pressed():
	var success = await multiplayer_manager.start_server()
	if success:
		hide()
		if server_label:
			server_label.text = "Server: " + multiplayer_manager.get_lan_ip() + ":7777"
			server_label.show()
	else:
		print("Failed to start server")

func _on_join_pressed():
	var ip = ""
	if ip_input:
		ip = ip_input.text.strip_edges()
	
	var success = await multiplayer_manager.join_server(ip)
	if success:
		hide()
	else:
		print("Failed to join server")
		show()

func show_ui():
	show()
	if server_label:
		server_label.hide()
