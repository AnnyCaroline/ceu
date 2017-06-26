## Locations

A location (aka *l-value*) is a path to a memory location holding a storage
entity ([`ID_int`](../lexical_rules/#identifiers)) or a native symbol
([`ID_nat`](../lexical_rules/#identifiers)).

Locations appear in assignments, event manipulation, iterators, and
expressions.

The list that follows summarizes all valid locations:

- storage entity: variable, vector, internal event (but not external), or pool
- native expression or symbol
- data field (which are storage entities)
- vector index
- vector length `$`
- pointer dereferencing `*`
- option unwrapping `!`

Locations are detailed in [Locations and Expressions](../expressions/#locations-expressions).

Examples:

```ceu
emit e(1);          // "e" is an internal event
_UDR = 10;          // "_UDR" is a native symbol
person.age = 70;    // "age" is a variable in "person"
vec[0] = $vec;      // "vec[0]" is a vector index
$vec = 1;           // "$vec" is a vector length
*ptr = 1;           // "ptr" is a pointer to a variable
a! = 1;             // "a" is of an option type
```
