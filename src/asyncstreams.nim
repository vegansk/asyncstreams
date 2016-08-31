#
#
#            Nim's Runtime Library
#        (c) Copyright 2016 Anatoly Galiulin
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#

import asyncdispatch, asyncnet, asyncfile

## This module provides the asynchronous stream interface and some of the implementations
## including ``AsyncStringStream``, ``AsyncFileStream`` and ``AsyncSocketStream``.
##
## If you want to implement your own asynchronous stream, you must provide the
## implementations of the streams operations as defined in ``AsyncStreamObj``.
## Also, you can use some helpers for the absent operations, like ``setPositionNotImplemented``,
## ``flushNop``, etc.
##
## Example:
##
## .. code-block:: Nim
##
##  import asyncdispatch, asyncstreams, strutils
##
##  proc main {.async.} =
##    var s = newAsyncStringStream("""Hello
##  world!""")
##    var res = newSeq[string]()
##    while true:
##      let l = await s.readLine()
##      if l == "":
##        break
##      res.add(l)
##    doAssert(res.join(", ") == "Hello, world!")
##  waitFor main()

type
  AsyncStream* = ref AsyncStreamObj
  AsyncStreamObj* = object of RootObj ## Asychronous stream interface.
    closeImpl*: proc (s: AsyncStream) {.gcsafe.}
    atEndImpl*: proc (s: AsyncStream): bool {.gcsafe.}
    setPositionImpl*: proc (s: AsyncStream; pos: int64) {.gcsafe.}
    getPositionImpl*: proc (s: AsyncStream): int64 {.gcsafe.}
    readDataImpl*: proc (s: AsyncStream; size: int): Future[string] {.gcsafe, tags: [ReadIOEffect].}
    writeDataImpl*: proc (s: AsyncStream; data: string): Future[void] {.gcsafe, tags: [WriteIOEffect].}
    flushImpl*: proc (s: AsyncStream): Future[void] {.gcsafe.}

#[###################################################################################################
# AsyncStream
]#

proc flush*(s: AsyncStream) {.async.}=
  ## Flushes the buffers of the stream ``s``.
  await s.flushImpl(s)

proc close*(s: AsyncStream) =
  ## Closes the stream ``s``.
  s.closeImpl(s)

proc atEnd*(s: AsyncStream): bool =
  ## Checks if all data has been read from the stream ``s``
  s.atEndImpl(s)

proc getPosition*(s: AsyncStream): int64 =
  ## Retrieves the current position in the stream ``s``
  s.getPositionImpl(s)

proc setPosition*(s: AsyncStream, pos: int64) =
  ## Sets the current position in the stream ``s``
  s.setPositionImpl(s, pos)

proc readData*(s: AsyncStream, size: int): Future[string] {.async.} =
  ## Reads up to the ``size`` bytes into the string from the stream ``s``
  result = await s.readDataImpl(s, size)

proc writeData*(s: AsyncStream, data: string) {.async.} =
  ## Writes ``data`` to the stream ``s``
  await s.writeDataImpl(s, data)

proc readChar*(s: AsyncStream): Future[char] {.async.} =
  ## Reads the char from the stream ``s``
  let data = await s.readData(1)
  result = if data.len == 0: '\0' else: data[0]

proc writeChar*(s: AsyncStream, c: char) {.async.} =
  ## Writes the char to the stream ``s``
  await s.writeData($c)

proc readLine*(s: AsyncStream): Future[string] {.async.} =
  ## Reads the line from the stream ``s`` until end of stream or the new line delimeter
  result = ""
  while true:
    let c = await s.readChar
    if c == '\c':
      await s.readChar
      break
    elif c == '\L' or c == '\0':
      break
    else:
      result.add(c)

proc writeLine*(s: AsyncStream, data: string) {.async.} =
  ## Writes the line from the stream ``s`` followed by the new line delimeter
  await s.writeData(data & "\n")

proc readAll*(s: AsyncStream): Future[string] {.async.} =
  ## Reads the data from the stream ``s`` until it's end
  result = ""
  while not s.atEnd:
    result &= await s.readData(4096)

# Imitate buffer API using strings
proc readBuffer*(s: AsyncStream, buffer: pointer, size: int): Future[int] {.async.} =
  ## Reads up to ``size`` bytes from the stream ``s`` into the ``buffer`` 
  let res = await s.readData(size)
  if res.len > 0:
    copyMem(buffer, res.cstring, res.len)
  result = res.len

# Imitate buffer API using strings
proc writeBuffer*(s: AsyncStream, buffer: pointer, size: int) {.async.} =
  ## Writes ``size`` bytes from the ``buffer`` into the stream ``s``
  var data = newString(size)
  copyMem(addr data[0], buffer, size)
  await s.writeData(data)

template checkEof(res: untyped): untyped =
  if not res:
    raise newException(IOError, "End of file exception")

proc readByte*(s: AsyncStream): Future[byte] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeByte*(s: AsyncStream, data: byte) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readInt8*(s: AsyncStream): Future[int8] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeInt8*(s: AsyncStream, data: int8) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readInt16*(s: AsyncStream): Future[int16] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeInt16*(s: AsyncStream, data: int16) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readInt32*(s: AsyncStream): Future[int32] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeInt32*(s: AsyncStream, data: int32) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readInt64*(s: AsyncStream): Future[int64] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeInt64*(s: AsyncStream, data: int64) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readUInt8*(s: AsyncStream): Future[uint8] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeUInt8*(s: AsyncStream, data: uint8) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readUInt16*(s: AsyncStream): Future[uint16] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeUInt16*(s: AsyncStream, data: uint16) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readUInt32*(s: AsyncStream): Future[uint32] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeUInt32*(s: AsyncStream, data: uint32) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readUInt64*(s: AsyncStream): Future[uint64] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeUInt64*(s: AsyncStream, data: uint64) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readInt*(s: AsyncStream): Future[int] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeInt*(s: AsyncStream, data: int) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readUInt*(s: AsyncStream): Future[uint] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeUInt*(s: AsyncStream, data: uint) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readFloat32*(s: AsyncStream): Future[float32] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeFloat32*(s: AsyncStream, data: float32) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readFloat64*(s: AsyncStream): Future[float64] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeFloat64*(s: AsyncStream, data: float64) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readFloat*(s: AsyncStream): Future[float] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeFloat*(s: AsyncStream, data: float) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

proc readBool*(s: AsyncStream): Future[bool] {.async.} =
  checkEof((await s.readBuffer(addr result, sizeof result)) == sizeof result)

proc writeBool*(s: AsyncStream, data: bool) {.async.} =
  var d = data
  await s.writeBuffer(addr d, sizeof d)

#[###################################################################################################
# ``Not implemented`` stuff
]#

proc setPositionNotImplemented*(s: AsyncStream; pos: int64) =
  doAssert(false, "setPosition operation is not implemented")

proc getPositionNotImplemented*(s: AsyncStream): int64 =
  doAssert(false, "getPosition operation is not implemented")

proc flushNotImplemented*(s: AsyncStream) {.async.} =
  doAssert(false, "flush operation is not implemented")

proc flushNop*(s: AsyncStream) {.async.} =
  discard

#[###################################################################################################
# AsyncFileStream
]#

type
  AsyncFileStream = ref AsyncFileStreamObj
  AsyncFileStreamObj = object of AsyncStreamObj
    f: AsyncFile
    eof: bool
    closed: bool

proc fileClose(s: AsyncStream) =
  let f = AsyncFileStream(s)
  f.f.close
  f.closed = true

proc fileAtEnd(s: AsyncStream): bool =
  let f = AsyncFileStream(s)
  f.closed or f.eof

proc fileSetPosition(s: AsyncStream, pos: int64) =
  AsyncFileStream(s).f.setFilePos(pos)

proc fileGetPosition(s: AsyncStream): int64 =
  AsyncFileStream(s).f.getFilePos

proc fileReadData(s: AsyncStream, size: int): Future[string] {.async.} =
  let f = AsyncFileStream(s)
  result = await  f.f.read(size)
  if result == "":
    f.eof = true

proc fileWriteData(s: AsyncStream; data: string) {.async.} =
  await AsyncFileStream(s).f.write(data)

proc initAsyncFileStreamImpl(res: var AsyncFileStreamObj, f: AsyncFile) =
  res.f = f
  res.closed = false

  res.closeImpl = fileClose
  res.atEndImpl = fileAtEnd
  res.setPositionImpl = fileSetPosition
  res.getPositionImpl = fileGetPosition
  res.readDataImpl = cast[type(res.readDataImpl)](fileReadData)
  res.writeDataImpl = cast[type(res.writeDataImpl)](fileWriteData)
  res.flushImpl = flushNop

proc newAsyncFileStream*(fileName: string, mode = fmRead): AsyncStream =
  var res = new AsyncFileStream
  initAsyncFileStreamImpl(res[], openAsync(fileName, mode))
  result = res

proc newAsyncFileStream*(f: AsyncFile): AsyncStream =
  var res = new AsyncFileStream
  initAsyncFileStreamImpl(res[], f)
  result = res

#[###################################################################################################
# AsyncStringStream
]#

type
  AsyncStringStream* = ref AsyncStringStreamObj
  AsyncStringStreamObj = object of AsyncStreamObj
    data: string
    pos: int
    eof: bool
    closed: bool

proc strClose(s: AsyncStream) =
  let str = AsyncStringStream(s)
  str.closed = true

proc strAtEnd(s: AsyncStream): bool =
  let str = AsyncStringStream(s)
  str.closed or str.eof

proc strSetPosition(s: AsyncStream, pos: int64) =
  let str = AsyncStringStream(s)
  str.pos = if pos.int > str.data.len: str.data.len else: pos.int

proc strGetPosition(s: AsyncStream): int64 =
  AsyncStringStream(s).pos

proc strReadData(s: AsyncStream, size: int): Future[string] {.async.} =
  let str = AsyncStringStream(s)
  doAssert(not str.closed, "AsyncStringStream is closed")
  result = str.data[str.pos..(str.pos+size-1)]
  str.pos += result.len
  if result.len == 0:
    str.eof = true

proc strWriteData(s: AsyncStream, data: string) {.async.} =
  let str = AsyncStringStream(s)
  doAssert(not str.closed, "AsyncStringStream is closed")
  if str.pos + data.len > str.data.len:
    str.data.setLen(str.pos + data.len)
  str.data[str.pos..(str.pos+data.len-1)] = data
  str.pos += data.len

proc `$`*(s: AsyncStringStream): string =
  s.data

proc newAsyncStringStream*(data = ""): AsyncStringStream =
  new result
  result.data = data

  result.closeImpl = strClose
  result.atEndImpl = strAtEnd
  result.setPositionImpl = strSetPosition
  result.getPositionImpl = strGetPosition
  result.readDataImpl = cast[type(result.readDataImpl)](strReadData)
  result.writeDataImpl = cast[type(result.writeDataImpl)](strWriteData)
  result.flushImpl = flushNop

#[###################################################################################################
# AsyncSocketStream
]#

type
  AsyncSocketStream = ref AsyncSocketStreamObj
  AsyncSocketStreamObj = object of AsyncStreamObj
    s: AsyncSocket
    closed: bool

proc sockClose(s: AsyncStream) =
  AsyncSocketStream(s).s.close
  AsyncSocketStream(s).closed = true

proc sockAtEnd(s: AsyncStream): bool =
  AsyncSocketStream(s).closed

proc sockReadData(s: AsyncStream, size: int): Future[string] {.async.} =
  result = await  AsyncSocketStream(s).s.recv(size)
  if result == "":
    AsyncSocketStream(s).closed = true

proc sockWriteData(s: AsyncStream; data: string) {.async.} =
  await AsyncSocketStream(s).s.send(data)

proc initAsyncSocketStreamImpl(res: var AsyncSocketStreamObj, s: AsyncSocket) =
  res.s = s
  res.closed = false

  res.closeImpl = sockClose
  res.atEndImpl = sockAtEnd
  res.setPositionImpl = setPositionNotImplemented
  res.getPositionImpl = getPositionNotImplemented
  res.readDataImpl = cast[type(res.readDataImpl)](sockReadData)
  res.writeDataImpl = cast[type(res.writeDataImpl)](sockWriteData)
  res.flushImpl = flushNop

proc newAsyncSocketStream*(s: AsyncSocket): AsyncStream =
  var res = new AsyncSocketStream
  initAsyncSocketStreamImpl(res[], s)
  result = res

