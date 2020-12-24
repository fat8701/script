#!/usr/bin/env bash


train="""
                 _-====-__-____-============-__
               _(                             _)
            OO(       Hello, Baby!            )_
           0  (_                               _)
         o0     (_                            _)
        o         \`=-___-===-_____-========-__)
      .o                                _________
     . ______          ______________  |         |      _____
   _()_||__|| ________ |            |  |_________|   __||___||__
  (         | |      | |            |  |Y_____00_|  |_         _|
/-OO----OO**=*OO--OO*=*OO--------OO*=*OO-------OO*=*OO-------OO*=P
"""

i=$(( $(stty size | cut -d" " -f2) - 67 ))

while [ $i -gt 1 ]; do
   clear
   tput setaf $(( $i % 7 + 1 ))
   printf "$train" | pr -tro $i
   sleep 0.5
   tput setf 0
   (( i = i - 1 ))
done
