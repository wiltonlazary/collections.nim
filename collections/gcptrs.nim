import macros, collections/nestedaccessor

export makeNestedAccessors

const useGcRef = not (compileOption("gc", "boehm") or compileOption("gc", "none"))

type
  gcptr*[T] = object
    p*: ptr T
    when useGcRef:
      gcref: RootRef

  SomeGcPtr* = gcptr[pointer]

  NullType* = object # type(nil) is not first class :(

const null* = NullType()

proc makeGcptr*[T](p: ptr T, gcref: RootRef): gcptr[T] =
  when useGcRef:
    return gcptr[T](p: p, gcref: gcref)
  else:
    return gcptr[T](p: p)

proc `+%`*[T](a: gcptr[T], b: int): gcptr[T] =
  return makeGcptr(cast[ptr T](cast[uint](a.p) +% sizeof(T) * b),
                   when useGcRef: a.gcref else: nil)

converter fromRef*[T](t: ref T): gcptr[T] =
  return makeGcptr(cast[ptr T](t), t.RootRef)

proc `==`*[T](a, b: gcptr[T]): bool =
  return a.p == b.p

proc unwrap*[T](p: SomeGcPtr, t: typedesc[ref T]): ref T {.inline.} =
  return cast[ref T](p.p)

proc unwrap*[T](p: SomeGcPtr, t: typedesc[gcptr[T]]): gcptr[T] {.inline.} =
  return cast[gcptr[T]](p)

proc unwrap*(p: SomeGcPtr, t: typedesc[NullType]): NullType {.inline.} =
  return null

proc toSomeGcPtr*[T](p: ref T): SomeGcPtr =
  return cast[SomeGcPtr](p.fromRef)

proc toSomeGcPtr*[T](p: gcptr[T]): SomeGcPtr =
  return cast[SomeGcPtr](p)

proc `[]`*[T](v: gcptr[T]): var T =
  return v.p[]

type
  FuncWrapper[T] = ref object of RootObj
    fun: (proc(): T)

template gclocaladdr*(v): expr =
  proc getAddr(): ptr type(v) = addr(v)
  makeGcptr(getAddr(), FuncWrapper[ptr type(v)](fun: getAddr))

macro gcaddr*(v): expr =
  # TODO: members of ref and gcptr types e.g:
  # TODO: gcaddr getFoo().bar where getFoo returns gcptr type
  return newCall(newIdentNode("gclocaladdr"), v)

template specializeGcPtr*(T) =
  # Nim doesn't have return type inference for converters :(
  converter fromNil*(t: NullType): gcptr[T] =
    return makeGcptr[T](nil, nil)

  makeNestedAccessors(T, gcptr[T])

specializeGcPtr(int)
specializeGcPtr(int8)
specializeGcPtr(int16)
specializeGcPtr(int32)
specializeGcPtr(int64)
specializeGcPtr(uint)
specializeGcPtr(uint8) # same as byte
specializeGcPtr(uint16)
specializeGcPtr(uint32)
specializeGcPtr(uint64)
specializeGcPtr(string)