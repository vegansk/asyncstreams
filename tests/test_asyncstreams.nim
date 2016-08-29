import unittest, asyncdispatch, asyncstreams, asyncnet, threadpool, os

const PORT = Port(9999)

suite "asyncstreams":

  proc runSocketServer =
    proc serve {.async.} =
      var s = newAsyncSocket()
      s.bindAddr(PORT)
      s.listen

      let c = newAsyncSocketStream(await s.accept)

      let ch = await c.readChar
      await c.writeChar(ch)

      let line = await c.readLine
      await c.writeLine("Hello, " & line)

      c.close
      s.close

    proc run {.gcsafe.} =
      waitFor serve()

    spawn run()

  test "AsyncSocketStream":
    runSocketServer()
    proc doTest {.async.} =
      let s = newAsyncSocket()
      await s.connect("localhost", PORT)
      let c = newAsyncSocketStream(s)

      await c.writeChar('A')
      let ch = await c.readChar
      check: ch == 'A'

      await c.writeLine("World!")
      let line = await c.readLine
      check: line == "Hello, World!"
    waitFor doTest()

  test "AsyncFileStream":
    proc doTest {.async.} =
      let fname = getTempDir() / "asyncstreamstest.nim"
      var s = newAsyncFileStream(fname, fmWrite)
      await s.writeLine("Hello, world!")
      s.close
      s = newAsyncFileStream(fname, fmRead)
      let line = await s.readLine
      check: line == "Hello, world!"
      check: not s.atEnd
      discard await s.readLine
      check: s.atEnd
      fname.removeFile
