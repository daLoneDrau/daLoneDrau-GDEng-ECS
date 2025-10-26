@abstract class_name CustomResource
extends Resource


## Gets the script's global name, if set; otherwise return the class name.
func get_class_name() -> String:
	var class_name_str: String = get_class()
	var script_instance = self.get_script()
	if script_instance:
		class_name_str = script_instance.get_global_name()
		var base_type_name = script_instance.get_instance_base_type()
		if "Component" in base_type_name:
			# this class extends a Component, such as ItemComponent, PlayerComponent. return the parent component script name
			class_name_str = base_type_name
	return class_name_str
