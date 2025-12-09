@abstract class_name CustomResource
extends Resource


## Gets the script's global name, if set; otherwise return the class name.
func get_class_name() -> String:
	var class_name_str: String = get_class()
	var script_instance: Script = self.get_script()
	if script_instance:
		class_name_str = script_instance.get_global_name()
		var base_script := script_instance.get_base_script()
		var base_type_name = script_instance.get_instance_base_type()
		if base_script != null:
			base_type_name = base_script.get_global_name()
		if "Component" in base_type_name and base_type_name != "EntityComponent":
			# this class extends a Component, such as ItemComponent, PlayerComponent. return the parent component script name
			class_name_str = base_type_name
	return class_name_str
