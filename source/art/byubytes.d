/**
This module provides functions to represent data structures as series of ubytes.

License: Distributed under the Boost Software License, Version 1.0.
(See accompanying file LICENSE_1_0.txt or copy at $(WEB
boost.org/LICENSE_1_0.txt)).

Authors: Iakh Takh
*/
module art.byubyte;

import std.traits;

//auto byUbytes(T)(const ref T t) pure @safe;

auto byUbytes(bytesUsed, T)(T val)
    if (isIntegral!T || isFloatingPoint!T || isBoolean!T || isSomeChar!T)
{
    enum size = T.sizeof;

    struct ReinterpretAsUByte
    {
        union
        {
            T v;
            ubyte[size] arr;
        }
    }

    ReinterpretAsUByte tmp;
    tmp.v = val;

    return tmp.arr;
}

/++ Represents its param as sequnce of ubytes that could be compared
with $(D memcmp) producing same result as default opCmp.
+/
auto byOrderedUbyte(T)(const ref T t) pure @safe;
