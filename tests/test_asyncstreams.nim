import unittest, asyncdispatch, asyncstreams, asyncnet, threadpool

const PORT = Port(9999)

suite "asyncstreams":

  proc runSocketServer =
    proc serve {.async.} =
      var s = newAsyncSocket()
      s.bindAddr(PORT)
      s.listen

      let c = await s.accept
      let req = await c.recvLine
      await c.send("Hello, " & req & "\c\L")
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
      await c.writeLine("World!")
      let rsp = await c.readLine
      check: rsp == "Hello, World!"
    waitFor doTest()
