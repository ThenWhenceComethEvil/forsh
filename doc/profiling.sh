#!/bin/bash
#
# Findings:
#     ALWAYS single quote arguments to `unset`. Don't evaluate anything. It
#     should receive a string, and handle the evaluation itself.
#
#     push to array   ::   array+=( "$value" )
#     pop from array  ::   unset 'array[$value]'
#
#     dyn var decls   ::   decl faster than eval
#     dyn fn decls    ::   eval w/ subshell faster than source w/ redirection,
#
#     loops           ::   while, double paren syntax, negative style

declare -a arr=()


function _push {
   time {
      for n in {1..250000} ; do
         ## speed:  abominatable
         #arr=( "$n"  "${arr[@]}" )

         ##  316k /s
         #arr[$n]="$n"

         ##  360k /s
         #arr+=( "$n" )

         ##  396k /s
         ##  Slightly faster, but requires knowing the index at which to insert.
         #arr[$n]='value'

         ##  390k /s
         arr+=( 'value,1' )
      done
   }
}


function _pop {
   time {
      for n in {0..50000} ; do
         ##  86k /s
         #unset arr[$n]

         ## 329k /s
         ## Super fast, but requires knowing the index at which to delete. Not
         ## a true `array.pop()`.
         #unset 'arr[$n]'

         ## Pop specifically the final element:

         ##  Literally forever.
         #arr=( "${arr[@]::${#arr[@]}-1}" )

         ##  58k /s
         #unset arr[-1]

         ## 175k /s
         unset 'arr[-1]'
      done
   }
}


# Cost of adding function parameters. Negligable, but exists.
function _fn_params {
   _f(){ :;}
   time {
      for n in {1..250000} ; do
         ##  297k /s
         _f

         ##  277k /s
         #_f 1

         ##  240k /s
         #_f 1 2

         ##  236k /s
         #_f 1 2 3
      done
   }
}


function _dyn_declare {
   time {
      for n in {1..250000} ; do
         ##  159k /s
         #eval "_${n}=$n"

         ##  263k /s
         declare _${n}="$n"
      done
   }
}


function _dyn_function {
   time {
      for n in {1..500} ; do
         ##  625 /s,  not thousand. Just... times. Oof.
         #source <(declare -f _push)

         ##  967 /s
         eval $(declare -f _push)
      done
   }
}


function _nameref {
   local var='this'
   time {
      for n in {1..250000} ; do
         ##  189k /s
         #eval "foo=\$var"

         ##  359k /s
         local -n foo='var'
      done
   }
}


function _subshell {
   # NOTES:
   # I did not realize how slow subshells actually are. Slower by like 50,000x
   # than function calls and whatnot.

   time {
      for n in {1..250000} ; do
         ##  819/s
         $( :; )

         ##  251k /s
         #eval ':'
      done
   }
}


function _loops {
   time {
      ## Known size, brace expansion.
      ##  663k /s
      #for n in {1..250000} ; do :; done

      ## Known size, C-style.
      ##  423k /s
      #for (( i=0 ; i<250000 ; ++i )) ; do :; done


      ## Variable size
      #local -i len=250000
      #local -i i=0

      ## While, increment
      ##  334k /s
      #while (( i < len )) ; do (( i++ )); :; done

      ## While, inverse style, brackets
      ##  376k /s
      #while [[ $len -ne 0 ]] ; do ((len--)); :; done

      ## C-style. Costs nothing, off by margin of error.
      ##  416k /s
      #for (( i=0 ; i<$len ; ++i )) ; do :; done

      ## While, inverse style, parens
      ##  440k /s
      #while (( len )) ; do (( len-- )); :; done

      ## C-style for loop
      ##  153k /s
      #for (( idx=0; idx<${#arr[@]}; idx++ )) ; do
      #   local __="${arr[$idx]}" ; :;
      #done

      ## Looping inverse via wile loop
      ##  162k /s
      #local -i idx="${#arr[@]}"
      #while (( idx )) ; do
      #   local __="${arr[-$idx]}"
      #   (( idx-- )) ; :;
      #done

      ## Looping over an array by index, and setting a value.
      ##  176k /s
      for n in "${!arr[@]}" ; do
         local __="${arr[$n]}" ; :;
      done


      ## Looping over an array by value
      ##  489k /s
      #for n in "${arr[@]}" ; do :; done
   }
}


function _declare {
   # Raw global declarations are fastest. Though `declare` and `local` (without
   # parameters) do the same thing in a function, `local` is slower. Huh. Both
   # are sufficiently fast that readable counts much more than any excessively
   # slight gains.

   time {
      for n in {1..250000} ; do
         ##  383k /s
         #declare -g __=''

         ##  382k /s
         #local __=''

         ##  423k /s
         #declare __=''

         ##  664k /s
         __=''
      done
   }
}


function _eval {
   # This is 2.5x slower. Just trying to get a ballpark for the overhead it
   # adds.

   time {
      for n in {1..250000} ; do
         ##  282k /s
         #eval ':'

         ##  696k /s
         :;
      done
   }
}


function _read_file {
   time {
      for n in {1..100} ; do
         ##  359/s
         #__=$( cat "${BASH_SOURCE[@]}" )

         ##  438/s
         #IFS= read -d '' __ < "${BASH_SOURCE[0]}"

         ##  943/s
         __=$(<"${BASH_SOURCE[@]}")
      done
   }
}


declare -gi _WORD_NUM=0
function word:new {
   (( ++_DICT_NUM ))
   local d="_FORTH_WORD_${_WORD_NUM}"
   declare -gA "$d"
   local -n d_r="$d"
   d_r=()
   LATEST="$d"
}
function _make_dict {
   time {
      for n in {1..10000} ; do
         ##  Calling function.
         ##  47k /s
         #word:new

         ##  Inline is 30% faster.
         ##  62k /s
         (( ++_DICT_NUM ))
         local d="_FORTH_WORD_${_WORD_NUM}"
         declare -gA "$d"
         local -n d_r="$d"
         d_r=()
         LATEST="$d"
      done
   }
}


function _double_pop {
   # nameref target for array item.
   declare -g value='this'

   for n in {1..50000} ; do
      # For nameref.
      arr+=( 1 'value' )

      # For decomposition.
      #arr+=( 'value,1' )
   done

   time {
      for n in {0..25000} ; do
         ##  179k /s
         ##  Decompose with intermediate variable.
         #local __="${arr[-1]}"
         #local -n __var="${__%%,*}"
         #local -- __num="${__##*,}"

         ##  208k /s
         ##  Remove a single item from the stack, decompose to parts.
         #local -n __var="${arr[-1]%%,*}"
         #local -- __num="${arr[-1]##*,}"
         #unset 'arr[-1]'

         #unset 'arr[-1]'
         ##  210k /s
         ##  Remove two items from the stack, assign both to vars.
         #local -n __var="${arr[-1]}" ; unset 'arr[-1]'
         #local -- __num="${arr[-1]}" ; unset 'arr[-1]'

         ##  243k /s
         ##  Unset both at the same time
         #local -n __var="${arr[-1]}"
         #local __num="${arr[-2]}"
         #unset 'arr[-1]' 'arr[-2]'

         ##  253k /s
         ##  Same as above, but with global variable for number.
         local -n __var="${arr[-1]}"
         __num="${arr[-2]}"
         unset 'arr[-2]' 'arr[-1]'
      done
   }
}


function _incr {
   local -i int=0

   time {
      for n in {1..250000} ; do
         ##  187k /s
         #(( ++int ))
         #local __="__${int}"
         #declare -g __n="$__"

         ##  202k /s
         local __="__$(( ++int ))"
         declare -g __n="$__"
      done
   }
}


function _index {
   time {
      for n in {1..250000} ; do
         ##  324k /s
         #var="${arr[$n]}"

         ##  347k /s
         var="${arr[n]}"
      done
   }
}

_push
for n in {1..20} ; do
   _index 2>&1
done
