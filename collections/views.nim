import collections/lang
import strutils

type
  View*[T] = object
    data*: pointer
    size*: int

  ConstView*[T] = object
    data*: pointer
    size*: int

  SomeView*[T] = View[T] | ConstView[T]

  ByteView* = View[byte]

proc emptyView*[T](): View[T] =
  result.data = nil
  result.size = 0

proc singleItemView*[T](item: var T): View[T] =
  View[T](data: addr item, size: 1)

proc seqView*[T](s: var seq[T]): View[T] =
  result.data = addr s[0]
  result.size = s.len

proc stringView*(s: var string): View[byte] =
  result.data = addr s[0]
  result.size = s.len

proc addrView*(s: cstring, size: int): View[byte] =
  result.data = cast[pointer](s)
  result.size = size

proc asView*(s: var string): auto = stringView(s)

proc asUnsafeView*(s: string): auto = addrView(s, s.len)

proc asView*(s: var seq): auto = seqView(s)

template asByteView*(s): ByteView =
  ByteView(data: s[0].unsafeAddr, size: s.len)

converter viewToConstView*[T](v: View[T]): ConstView[T] =
  result.data = v.data
  result.size = v.size

proc isNil*(v: View): bool =
  return v.data == nil

proc len*(v: View): int =
  v.size

proc len*(v: ConstView): int =
  v.size

proc asPointer*[T](v: SomeView[T]): ptr T =
  cast[ptr T](v.data)

proc ptrAdd[T](p: pointer, i: int): ptr T =
  return cast[ptr T](cast[int](p) +% (i * sizeof(T)))

proc `[]`*[T](v: ConstView[T], i: int): T =
  doAssert(i >= 0 and i < v.size)
  return ptrAdd[T](v.data, i)[]

proc `[]`*[T](v: View[T], i: int): var T =
  doAssert(i >= 0 and i < v.size)
  return ptrAdd[T](v.data, i)[]

proc `[]=`*[T](v: View[T], i: int, val: T) =
  doAssert(i >= 0 and i < v.size)
  ptrAdd[T](v.data, i)[] = val

proc slice*[T](v: SomeView[T], start: int, size: int): SomeView[T] =
  if size != 0:
    doAssert(start < v.len and start >= 0)
    doAssert(start + size <= v.len)
    doAssert(size >= 0)
    result.data = ptrAdd[T](v.data, start)
    result.size = size
  else:
    result.data = nil
    result.size = 0

proc slice*[T](v: SomeView[T], start: int): SomeView[T] =
  assert start <= v.len and start >= 0
  return v.slice(start, v.len - start)

type ScalarType = uint8 | uint16 | uint32 | uint64 | int8 | int16 | int32 | int64 | float32 | float64 | byte | char | enum

proc copyFrom*[T](dst: View[T], src: SomeView[T]) =
  assert dst.size >= src.size
  when T is ScalarType:
    copyMem(dst.data, src.data, src.size * sizeof(T))
  else:
    for i in 0..<src.size:
      ptrAdd[T](dst.data, i)[] = ptrAdd[T](src.data, i)[]

proc copyTo*[T](src: SomeView[T], dst: View[T]) =
  dst.copyFrom(src)

proc copyAsSeq*[T](src: ConstView[T]): seq[T] =
  result = newSeq[T](src.len)
  src.copyTo(result.seqView)

proc copyAsString*(src: SomeView[byte]): string =
  result = newString(src.len)
  src.copyTo(result.stringView)

proc copyAs*[R, T](src: SomeView[R], t: typedesc[T]): T =
  when t is seq:
    return copyAsSeq[R](src)
  else:
    return copyAsString(src)

iterator items*[T](src: SomeView[T]): T =
  for i in 0..<src.len:
    yield src[i]

proc `$`*[T](v: SomeView[T]): string =
  return "View[$1, $2]" % [$v.len, $v.copyAsSeq]

proc clearIfReferenceType*[T](view: SomeView[T]) =
  ## Clears `view` if it contains GC type
  when not (T is ScalarType):
    for i in 0..<view.size:
      ptrAdd[T](view.data, i)[] = defaultVal(T)

proc alignedStringView*(s: var string, align=16): ByteView =
  ## Return view into string ``s``. Align it to ``align`` bytes if needed.
  let misaligned = cast[int](addr s[0]) mod align
  if misaligned != 0:
    s = " ".repeat(align - misaligned) & s
    return s.stringView.slice(align - misaligned)
  return s.stringView
