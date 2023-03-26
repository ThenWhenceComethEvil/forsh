#!/usr/bin/bats
# vim: ft=sh

function setup {
   load '/usr/lib/bats-assert/load.bash'
   load '/usr/lib/bats-support/load.bash'

   local dir="${BATS_TEST_DIRNAME}/../"
   export src="${dir}/forsh"
   source "$src"
}


@test 'words end in EXIT' {
   for word in ${!word_*} ; do
      if [[ "$word" == word_QUIT ]] ; then
         continue
      fi

      local -n word_r="$word"
      (( word_r[-1] == CACHE['EXIT'] ))
   done
}


@test 'codes end in NEXT' {
   for word in "${!CACHE[@]}" ; do
      local index="${CACHE[$word]}"
      local fn="${M[$index]}" 

      if [[ "$fn" == 'DOCOL'          ]] ; then continue ; fi
      if [[ "$fn" == 'code_BYE'       ]] ; then continue ; fi
      if [[ "$fn" == 'code_INTERPRET' ]] ; then continue ; fi

      local found=0
      while read -r line ; do
         if [[ "$line" == *NEXT* ]] ; then
            found=1
         fi
      done < <(declare -f "$fn")

      (( found ))
   done
}


@test 'CACHE always refers to valid words' {
   skip 'Does not yet work, may need to put ${CACHE[]}s 1 per line'

   local text=$(<$src)
   local -A words=()

   while read -r line ; do
      if [[ "$line" =~ ^def_(code|word)[[:space:]]+([^[:space:]]+) ]] ; then
         w="${BASH_REMATCH[2]}"

         # Remove surrounding quotes.
         if [[ "$w" =~ \'([^\']+)\' ]] ; then w="${BASH_REMATCH[1]}" ; fi
         if [[ "$w" =~ \"([^\"]+)\" ]] ; then w="${BASH_REMATCH[1]}" ; fi

         words["$w"]=1
      fi
   done <<< "$text"

   while read -r line ; do
      # TODO: This won't work while I have multiple CACHE statements per line.
      if [[ "$line" =~ \$\{CACHE\[([^]]+)]\} ]] ; then
         printf 'w: %s\n'  "${BASH_REMATCH[@]:1}"  1>&3
      fi
   done <<< "$text"
}
