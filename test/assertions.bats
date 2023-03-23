#!/usr/bin/bats
# vim: ft=sh

function setup {
   load '/usr/lib/bats-assert/load.bash'
   load '/usr/lib/bats-support/load.bash'

   local dir="${BATS_TEST_DIRNAME}"
   source "${dir}/forsh"
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

      #echo "testing word($word) at index ($index) :: $fn"  1>&3
      (( found ))
   done
}
