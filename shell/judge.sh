is_int() { #? Check if value(s) is integer
	local param
	for param; do
		if [[ ! $param =~ ^[\-]?[0-9]+$ ]]; then return 1; fi
	done
}

is_float() { #? Check if value(s) is floating point
	local param
	for param; do
		if [[ ! $param =~ ^[\-]?[0-9]*[,.][0-9]+$ ]]; then return 1; fi
	done
}

is_hex() { #? Check if value(s) is hexadecimal
	local param
	for param; do
		if [[ ! ${param//#/} =~ ^[0-9a-fA-F]*$ ]]; then return 1; fi
	done
}