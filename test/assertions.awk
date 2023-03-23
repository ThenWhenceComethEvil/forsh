#!/usr/bin/awk -f
#
# For each `function code_XXX` definition, there must be an immediately
# following call to `def_code` with then function name as the final parameter.

/^function\s+code_/ {
   fn_name = $2
}

fn_name &&
/^def_code\s+/ {
   if ($4 != fn_name) {
      print "def_code("  $4  "), expected: " fn_name > "/dev/stderr"
      exit 1
   }
   fn_name = ""
}
