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
         arr+=( 'value' )
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



for n in {1..20} ; do
   _declare 2>&1
done
