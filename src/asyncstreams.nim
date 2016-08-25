import asyncdispatch, asyncnet

type
  AsyncStream* = ref AsyncStreamObj
  AsyncStreamObj* = object of RootObj
    closeImpl*: proc (s: AsyncStream) {.gcsafe.}
    atEndImpl*: proc (s: AsyncStream): bool {.gcsafe.}
    setPositionImpl*: proc (s: AsyncStream; pos: int64) {.gcsafe.}
    getPositionImpl*: proc (s: AsyncStream): int64 {.gcsafe.}
    readDataImpl*: proc (s: AsyncStream; size: int): Future[string] {.gcsafe, tags: [ReadIOEffect].}
    writeDataImpl*: proc (s: AsyncStream; data: string): Future[void] {.gcsafe, tags: [WriteIOEffect].}
    flushImpl*: proc (s: AsyncStream): Future[void] {.gcsafe.}

####################################################################################################
# AsyncStream

proc readChar*(s: AsyncStream): Future[char] {.async.} =
  let data = await s.readDataImpl(s, 1)
  result = if data.len == 0: '\0' else: data[0]

proc readLine*(s: AsyncStream): Future[string] {.async.} =
  result = ""
  while true:
    let c = await s.readChar
    if c == '\c':
      asyncCheck s.readChar
      break
    elif c == '\L' or c == '\0':
      break
    else:
      result.add(c)

proc writeLine*(s: AsyncStream, data: string) {.async.} =
  asyncCheck s.writeDataImpl(s, data & "\c\L")

####################################################################################################
# ``Not implemented`` stuff

proc setPositionNotImplemented(s: AsyncStream; pos: int64) =
  doAssert(false, "setPosition operation is not implemented")

proc getPositionNotImplemented(s: AsyncStream): int64 =
  doAssert(false, "getPosition operation is not implemented")

proc flushNotImplemented(s: AsyncStream) {.async.} =
  doAssert(false, "flush operation is not implemented")

####################################################################################################
# AsyncSocketStream

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
  res.flushImpl = flushNotImplemented

proc newAsyncSocketStream*(s: AsyncSocket): AsyncStream =
  var res = new AsyncSocketStream
  initAsyncSocketStreamImpl(res[], s)
  result = res

