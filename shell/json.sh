#--- json_escape_string() - Format a string value according to JSON syntax (no unicode for now) ---
function json_escape_string() {
	sed -E '$!N; s/(["\\\/])/\\\1/g; s/\'$'\b''/\\b/g; s/\n/\\n/g; s/\'$'\t''/\\t/g; s/\'$'\f''/\\f/g; s/\'$'\r''/\\r/g' <<<"$*" | tr -d '\n'
}

#--- json_unescape_string() - Convert a JSON string (without quotes) to native bash format ---
function json_unescape_string() {
	sed -E 's/\\"/"/g; s#\\/#/#g; s/\\b/'$'\b''/; s/\\n/\'$'\n''/g; s/\\t/\'$'\t''/g; s/\\f/\'$'\f''/g; s/\\r/\'$'\r''/g; s/\\\\/\\/g' <<<"$*"
}

#--- json_array() - Format a JSON array ---
function json_array() {
	local sep=''
	echo -n "["
	#--- Print each argument as a JSON element ---
	for value in "$@"; do
                #--- Quote value ---
                echo -n "$sep\"`json_escape_string "$value"`\""
		#--- Add a seperator for subsequent elements ---
		sep=', '
	done
	#--- Close JSON reponse ---
	echo "]"
}

#--- json_dict() - Format a JSON dictionary ---
function json_dict() {
	local var
	local sep=''
	echo -n "{"
	#--- Print each argument as a JSON element ---
	for var in "$@"; do
		#--- var=value : String value supplied inline, escape string for JSON  ---
		if [[ "$var" =~ ^([^=]*)=(.*)$ ]]; then
			echo -n "$sep\"${BASH_REMATCH[1]}\": \"`json_escape_string "${BASH_REMATCH[2]}"`\""
		#--- var:value : Raw JSON value supplied inline, don't escape ---
		elif [[ "$var" =~ ^([^:]*):(.*)$ ]]; then
			echo -n "$sep\"${BASH_REMATCH[1]}\": ${BASH_REMATCH[2]}"
		#--- var : String value is to be obtained from bash environment variables ---
		else
			echo -n "$sep\"$var\": \"`json_escape_string "${!var}"`\""
		fi
		#--- Add a seperator for subsequent elements ---
		sep=', '
	done
	#--- Close JSON reponse ---
	echo "}"
}