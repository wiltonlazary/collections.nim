import collections/weakref, tables, macros

type
  WeakValueTable*[K, V] = ref object of WeakRefable
    t: Table[K, WeakRef[V]]

proc newWeakValueTable*[K, V](self: var WeakValueTable[K, V]) =
  ## Creates a table, which doesn't prevent its value from being destructed.
  ## (when this happens, the key-value pair is removed from table).
  static:
    if not (V is ref WeakRefable):
      error("WeakValueTable values must be references and inherit from WeakRefable")

  self = newWeakRefable(type(self))
  self.t = initTable[K, WeakRef[V]]()

proc `$`*(self: WeakValueTable): string =
  var s = "WeakValueTable ("
  for k, v in self.t.pairs:
    s.add(($k) & " = " & ($v.lock) & ", ")
  return s & ")"

proc contains*[K, V](self: WeakValueTable[K, V], k: K): bool =
  return k in self.t

proc `[]`*[K, V](self: WeakValueTable[K, V], k: K): V =
  return self.t[k].lock

proc len*(self: WeakValueTable): int =
  return self.t.len

proc addKey*[K, V](self: WeakValueTable[K, V], k: K): V =
  let weakSelf = self.weakRef

  proc free(r: pointer) =
    if not weakSelf.isAlive: return
    let self = weakSelf.lock()

    if k in self.t and cast[pointer](self.t[k].rawPointer) == nil:
      del self.t, k

  let r = newWeakRefable(V, free)
  self.t[k] = r.weakRef
  return r